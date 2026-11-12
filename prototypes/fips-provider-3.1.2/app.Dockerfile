# syntax=docker/dockerfile:1.10
# PROTOTYPE (Odoo 5886): the app copy on top of the FIPS image. Build context = the scratch copy of the app.
FROM thecore-fips-prototype
COPY . /app
# FINDING: with fips=yes Bundler (2.5.22 and 4.0.24, fetcher/compact_index.rb) refuses the CompactIndex API
# ("FIPS mode is enabled, bundler can't use the CompactIndex API": it uses MD5) and falls back to fetching
# every gemspec on rubygems.org, which never ends. So the install runs with OpenSSL's default config (empty
# OPENSSL_CONF = default provider); fips=yes applies again to everything after this step.
RUN --mount=type=secret,id=bundle,env=BUNDLE_GEMS__BANCOLINI__COM \
    OPENSSL_CONF=/dev/null bundle install --jobs 8 --quiet
