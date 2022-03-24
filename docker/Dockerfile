FROM gabrieletassoni/thecore:2

# Copy the Rails Appplication leaving out the .dockrignored file
ADD . /app

RUN ls -l /app/vendor/bundle/ruby/*/gems/

SHELL ["/bin/bash", "-c"]
