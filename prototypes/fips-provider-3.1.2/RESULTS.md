# PROTOTIPO FIPS livello B: risultati (Odoo 5886, 2026-11-12)

Branch usa e getta `prototype/fips-provider-3.1.2`: mai unito, mai pubblicato. Domanda: il livello B
(trixie + provider OpenSSL FIPS 3.1.2, cert. CMVP #4985, `fips=yes`) è praticabile per mytask?

**Verdetto: sì, tecnicamente.** mytask (host 3.23.x, Rails 7.2.4, Ruby 3.3.13) parte, fa login API
(bcrypt + JWT HS256), parla con PostgreSQL in TLS 1.3 + SCRAM e con SQL Server in TLS, tutto attraverso
il provider FIPS. Si rompe solo ciò che usa MD5 tramite OpenSSL: Active Storage e l'autenticazione `md5`
di PostgreSQL. Restano aperti punti di conformità, non di funzionamento (sotto).

Come rifarlo: `BUNDLE_GEMS__BANCOLINI__COM=... bash prototypes/fips-provider-3.1.2/run.sh <backend>`
(`DOCKER="sudo -E docker"` se il socket non è del gruppo docker); `run.sh --down` pulisce.

## Build

| | |
| --- | --- |
| Immagine base FIPS (provider 3.1.2 + FreeTDS 1.5.19 + runtime) | 57 s a freddo su 20 CPU, 20 s con cache |
| Dimensione | 1,88 GB (oggi `thecore:3` 2,16 GB, ma il prototipo non ha tutti i pacchetti di `Dockerfile.common`) |
| `bundle install` dell'app (pg/tiny_tds `force_ruby_platform`) | 37 s |
| Tarball OpenSSL 3.1.2 | SHA-256 `a0ce69b8…6d6539`, uguale al `.sha256` pubblicato |

## Cosa funziona con `fips=yes` (solo provider FIPS + base, nessun default)

- Ruby openssl: OpenSSL 3.5.7 di trixie come core, `OpenSSL.fips_mode = true`, provider "OpenSSL FIPS Provider" 3.1.2.
- `pg` compilato da sorgente → `libpq.so.5` di sistema → libssl di sistema. Connessione `sslmode=require`: TLS 1.3, `TLS_AES_256_GCM_SHA384`, SCRAM-SHA-256.
- `tiny_tds` compilato contro FreeTDS 1.5.19 costruito `--with-openssl` (il `libsybdb5` di Debian usa **GnuTLS**). Con `encryption = require` in `freetds.conf` la sessione è cifrata (`encrypt_option = TRUE`); l'opzione `encryption:` di `TinyTds::Client` viene ignorata.
- SHA-256, SHA-1 digest, HMAC-SHA1, PBKDF2-SHA256 600k, AES-256-GCM, RSA-2048, EC P-256 (VAPID).
- Rails: key generator SHA-256, `MessageVerifier`, `MessageEncryptor`, cookie firmati e cifrati, JWT HS256, Devise/bcrypt, login `POST /api/v2/authenticate` → 200 con token.
- Test suite: 480 test; con FIPS 9 errori, senza FIPS (stessa immagine, `OPENSSL_CONF=/dev/null`) 4. Le 4 comuni sono dati sporchi del DB di prova (`Key has already been taken`), non FIPS.

## Cosa si rompe

1. **Active Storage**: ogni `attach`/upload → `OpenSSL::Digest::DigestError` (MD5). Sono i 5 test in più (`BusinessDataResetTest`, allega un PDF). Nell'app: PDF dei report, foto. Serve l'override del checksum (SHA-256) o MD5 dichiarato come checksum non di sicurezza fuori dal provider.
2. **PostgreSQL con `md5` in `pg_hba.conf`**: `could not encrypt password: unsupported`. Serve SCRAM-SHA-256 (le immagini `postgres` ufficiali lo usano già di default).
3. **Bundler**: con `fips=yes` rifiuta la CompactIndex API ("FIPS mode is enabled, bundler can't use the CompactIndex API", ancora in Bundler 4.0.24) e ripiega sull'indice completo di rubygems.org: in pratica non finisce mai. `bundle install` va fatto con FIPS spento (`OPENSSL_CONF=/dev/null`) nella fase di build; a runtime nessun problema.

## Conformità: cosa il prototipo non chiude

- **Ambiente operativo**: la Security Policy #4985 elenca Debian 11.5 e Ubuntu 22.04 testati, **nessun ambiente vendor affirmed**; trixie non c'è. Il rimando a un'Appendice A sul porting non trova l'appendice nel documento (89 pagine). Dichiarabile come "porting a cura dell'utente" **[inferenza, IG 2.3 non riletta]**, con meno garanzia di un ambiente testato.
- **Installazione**: la policy vuole i passi "on each platform where it is intended to be used" e `fipsinstall -pedantic`. Il prototipo genera il config nell'immagine con `-self_test_onload` (self-test a ogni caricamento); se basta, o se serve `fipsinstall` all'avvio del container, è da decidere.
- **IV di AES-GCM**: in approved mode "an IV must not be imported for encryption from outside the cryptographic boundary". `MessageEncryptor`, i cookie cifrati e Active Record Encryption passano l'IV dall'esterno (`cipher.random_iv` → `iv=`): funziona, ma è una non conformità formale.
- **Fuori dal provider, senza errori**: bcrypt (C proprio), `Digest::MD5` di Ruby, `SecureRandom` (kernel), smbclient (GnuTLS di Debian non convalidata; NTLM funziona anche con `GNUTLS_FORCE_FIPS_MODE=1`). Vanno migrati (PBKDF2) o dichiarati come eccezioni.
- Active Record Encryption ha `hash_digest_class = SHA1` (`load_defaults 7.0`): funziona, ma va portato a SHA-256 con `load_defaults` ≥ 7.1.
