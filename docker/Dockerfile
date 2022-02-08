FROM gabrieletassoni/thecore:latest

# Copy the Rails Appplication leaving out the .dockrignored file
ADD . /app

# # Install This instance specific dependecies
# RUN bundle config set gems.bancolini.com 'test-gem:pulled-verify-Warner-78' \
#     && bundle update

# # This means that RAILS_RELATIVE_URL will always be /, no suburi support by now
# RUN SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake /app/bin/rails --trace assets:precompile \
#     && rm -rf tmp/cache/* /tmp/*

#forward request and error logs to docker log collector
# RUN ln -sf /dev/stdout /app/log/latest-startup.log \
#     && ln -sf /dev/stderr /app/log/latest-startup.log
SHELL ["/bin/bash", "-c"]
