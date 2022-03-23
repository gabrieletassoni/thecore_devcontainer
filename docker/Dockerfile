FROM gabrieletassoni/thecore:2

ARG BUILD_DIR

# Copy the Rails Appplication leaving out the .dockrignored file
ADD $BUILD_DIR/. /app

RUN ls -l /app/

SHELL ["/bin/bash", "-c"]
