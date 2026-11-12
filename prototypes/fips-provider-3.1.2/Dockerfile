# PROTOTYPE — Odoo 5886, wayfinder map 5861. Throwaway: never built by CI, never published, never merged.
# Question: is FIPS "level B" feasible? (trixie + OpenSSL FIPS provider 3.1.2, cert #4985, built per its
# Security Policy, fips=yes, pg/tiny_tds compiled against the system libssl.)

# --- 1. OpenSSL FIPS provider 3.1.2 from the validated tarball -------------------------------------------
FROM ruby:3.3.13-trixie AS fips
ARG OPENSSL_FIPS_VERSION=3.1.2
ARG OPENSSL_FIPS_SHA256=a0ce69b8b97ea6a35b96875235aa453b966ba3cba8af2de23657d8b6767d6539
RUN curl -fsSLo /tmp/openssl.tar.gz https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_FIPS_VERSION}/openssl-${OPENSSL_FIPS_VERSION}.tar.gz \
    && echo "${OPENSSL_FIPS_SHA256}  /tmp/openssl.tar.gz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/openssl.tar.gz \
    && cd /tmp/openssl-${OPENSSL_FIPS_VERSION} \
    && ./Configure enable-fips --prefix=/opt/openssl-fips --libdir=lib \
    && make -j"$(nproc)" \
    && make install_sw install_fips

# --- 2. FreeTDS on OpenSSL (Debian's libsybdb5 links GnuTLS) ------------------------------------------------
FROM ruby:3.3.13-trixie AS freetds
ARG FREETDS_VERSION=1.5.19
RUN curl -fsSLo /tmp/freetds.tar.gz https://www.freetds.org/files/stable/freetds-${FREETDS_VERSION}.tar.gz \
    && tar -C /tmp -xzf /tmp/freetds.tar.gz \
    && cd /tmp/freetds-${FREETDS_VERSION} \
    && ./configure --prefix=/opt/freetds --with-openssl --without-gnutls --disable-odbc --disable-apps \
    && make -j"$(nproc)" \
    && make install

# --- 3. Runtime ---------------------------------------------------------------------------------------------
FROM ruby:3.3.13-trixie
RUN apt-get update \
    && apt-get -y install --no-install-recommends smbclient poppler-utils libvips-dev imagemagick postgresql-client \
       libcap-dev libcups2-dev libgirepository1.0-dev libicu-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fips /opt/openssl-fips /opt/openssl-fips
COPY --from=freetds /opt/freetds /opt/freetds
RUN cp /opt/openssl-fips/lib/ossl-modules/fips.so "$(openssl version -m | sed -E 's/.*"(.*)"/\1/')/fips.so" \
    && echo /opt/freetds/lib > /etc/ld.so.conf.d/freetds.conf && ldconfig

# Module config without the install-status/MAC indicators: the self-tests run at every load, so the file can
# ship in an image (fipsinstall(1), -self_test_onload). Generated with the validated build's own openssl.
RUN LD_LIBRARY_PATH=/opt/openssl-fips/lib /opt/openssl-fips/bin/openssl fipsinstall -self_test_onload \
      -module "$(openssl version -m | sed -E 's/.*"(.*)"/\1/')/fips.so" -out /usr/lib/ssl/fipsmodule.cnf
# Last: from here on every OpenSSL consumer in the image is fips=yes, with no default provider to fall back to.
COPY openssl.cnf /usr/lib/ssl/openssl.cnf

ENV FREETDS_DIR=/opt/freetds BUNDLE_PATH=/bundle
WORKDIR /app
