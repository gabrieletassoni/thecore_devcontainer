FROM gabrieletassoni/thecore:2

# Copy the Rails Appplication leaving out the .dockrignored file
ADD . /app

#forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /app/log/latest-startup.log \
    && ln -sf /dev/stderr /app/log/latest-startup.log

SHELL ["/bin/bash", "-c"]
