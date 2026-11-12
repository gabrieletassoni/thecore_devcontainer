# PROTOTYPE (Odoo 5886): run with `bin/rails runner probe.rb` inside the FIPS image. Prints one line per check.
require "open3"

def check(name)
  result = yield
  puts "OK    #{name}: #{result}"
rescue Exception => e # rubocop:disable Lint/RescueException
  puts "FAIL  #{name}: #{e.class}: #{e.message.lines.first&.strip}"
end

check("ruby openssl") { "#{OpenSSL::OPENSSL_LIBRARY_VERSION}, fips_mode=#{OpenSSL.fips_mode}" }
check("providers") { Open3.capture2e("openssl", "list", "-providers")[0].scan(/name: (.*)/).flatten.join(" | ") }
check("pg linkage") { `ldd #{Gem.loaded_specs['pg'].extension_dir}/pg_ext.so`.scan(/lib(?:ssl|crypto|pq)\S*/).uniq.join(" ") }
check("tiny_tds linkage") { `ldd #{Gem.loaded_specs['tiny_tds'].extension_dir}/tiny_tds/tiny_tds.so`.scan(/lib(?:ssl|crypto|gnutls|sybdb)\S*/).uniq.join(" ") }
check("smbclient linkage") { `ldd /usr/bin/smbclient`.scan(/lib(?:ssl|crypto|gnutls)\S*/).uniq.join(" ") }

check("OpenSSL SHA-256") { OpenSSL::Digest::SHA256.hexdigest("x")[0, 16] }
check("OpenSSL MD5") { OpenSSL::Digest::MD5.hexdigest("x") }
check("OpenSSL SHA-1 digest") { OpenSSL::Digest::SHA1.hexdigest("x")[0, 16] }
check("HMAC-SHA1") { OpenSSL::HMAC.hexdigest("SHA1", "k" * 32, "x")[0, 16] }
check("Ruby Digest::MD5 (not OpenSSL)") { Digest::MD5.hexdigest("x")[0, 16] }
check("PBKDF2-SHA256 600k") { OpenSSL::KDF.pbkdf2_hmac("pw", salt: SecureRandom.bytes(16), iterations: 600_000, length: 32, hash: "SHA256").bytesize }
check("PBKDF2 short salt (13 B)") { OpenSSL::KDF.pbkdf2_hmac("pw", salt: "signed cookie", iterations: 1000, length: 64, hash: "SHA1").bytesize }
check("AES-256-GCM") { c = OpenSSL::Cipher.new("aes-256-gcm").encrypt; c.key = SecureRandom.bytes(32); c.iv = SecureRandom.bytes(12); (c.update("x") + c.final).bytesize }
check("RSA-2048 keygen") { OpenSSL::PKey::RSA.new(2048).n.num_bits }
check("EC P-256 (VAPID)") { OpenSSL::PKey::EC.generate("prime256v1").group.curve_name }
check("bcrypt (own C, not OpenSSL)") { BCrypt::Password.create("pw", cost: 4).is_password?("pw") }

check("Rails key_generator digest") { Rails.application.config.active_support.key_generator_hash_digest_class.inspect }
check("Rails secret key derivation") { Rails.application.key_generator.generate_key("signed cookie", 64).bytesize }
check("MessageVerifier") { v = Rails.application.message_verifier(:probe); v.verify(v.generate("x")) }
check("MessageEncryptor") { k = ActiveSupport::KeyGenerator.new("s" * 64).generate_key("salt" * 4, 32); e = ActiveSupport::MessageEncryptor.new(k); e.decrypt_and_verify(e.encrypt_and_sign("x")) }
check("signed cookie jar") do
  req = ActionDispatch::TestRequest.create
  req.cookie_jar.signed[:p] = "x"
  req.cookie_jar.signed[:p]
end
check("encrypted cookie jar") do
  req = ActionDispatch::TestRequest.create
  req.cookie_jar.encrypted[:p] = "x"
  req.cookie_jar.encrypted[:p]
end
check("JWT HS256") { JWT.decode(JWT.encode({ a: 1 }, "k" * 32, "HS256"), "k" * 32, true, algorithm: "HS256").first["a"] }
check("Devise user password") { u = User.new(password: "Probe-pw-123"); u.valid_password?("Probe-pw-123") }
check("Active Storage upload (MD5 checksum)") { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("x"), filename: "p.txt").checksum }
check("Active Storage SHA-256 override hint") { ActiveStorage::Blob.method_defined?(:compute_checksum_in_chunks, false) }
check("AR Encryption hash digest") { ActiveRecord::Encryption.config.hash_digest_class.inspect }

check("PostgreSQL TLS + SCRAM") do
  conn = PG.connect(ENV.fetch("PROBE_PG_URL"))
  r = conn.exec("SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid()").first
  conn.close
  r.values.join(" ")
end
check("PostgreSQL md5 auth") { PG.connect(ENV.fetch("PROBE_PG_MD5_URL")).close; "connected" }

%w[require off].each do |enc|
  check("SQL Server TDS encryption=#{enc}") do
    c = TinyTds::Client.new(host: "fips-mssql", username: "sa", password: ENV.fetch("PROBE_MSSQL_PASSWORD"),
                            encryption: enc, login_timeout: 10, tds_version: "7.4")
    r = c.execute("SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID").first
    c.close
    "encrypt_option=#{r['encrypt_option']}"
  end
end

check("smbclient NTLM (system crypto)") do
  out, st = Open3.capture2e("smbclient", "//fips-smb/share", "-U", "probe%probe-pw", "-c", "ls", "-m", "SMB3")
  raise out.lines.last.to_s unless st.success?
  "listed"
end
check("smbclient NTLM, GNUTLS_FORCE_FIPS_MODE=1") do
  out, st = Open3.capture2e({ "GNUTLS_FORCE_FIPS_MODE" => "1" }, "smbclient", "//fips-smb/share", "-U", "probe%probe-pw", "-c", "ls", "-m", "SMB3")
  raise out.lines.last.to_s unless st.success?
  "listed"
end
