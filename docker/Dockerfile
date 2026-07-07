FROM gabrieletassoni/thecore:3

# Copy the Rails Appplication leaving out the .dockrignored file
ADD . /app

SHELL ["/bin/bash", "-c"]

RUN --mount=type=secret,id=bundle_env \
    set -a; [ -f /run/secrets/bundle_env ] && . /run/secrets/bundle_env; set +a; \
    bundle config set path "/app/vendor/bundle" \
    && bundle config get path \
    && bundle install \
    && rm -rf tmp/cache/* /tmp/*
