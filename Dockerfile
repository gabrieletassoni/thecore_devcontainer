# Build Arguments
ARG VARIANT=2
FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${VARIANT}

# Installing the base thecore gems
RUN gem install rails:'~> 6.0' \
    pg:'~> 1.2' \
    thecore_auth_commons:2.2.8 \
    thecore_backend_commons:2.3.0 \
    thecore_background_jobs:2.0.1 \
    thecore_ftp_helpers:2.0.6 \
    thecore_ui_commons:2.2.0 \
    thecore_ui_rails_admin:2.2.1 \
    thecore_dataentry_commons:2.0.4

# Creating the git clones of thecore gems
WORKDIR /workspaces
RUN mkdir -p thecore
RUN chown -R vscode /workspaces/thecore
USER vscode
WORKDIR /workspaces/thecore
RUN git clone https://github.com/gabrieletassoni/model_driven_api.git \
    && git clone https://github.com/gabrieletassoni/thecore_auth_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_backend_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_background_jobs.git \
    && git clone https://github.com/gabrieletassoni/thecore_dataentry_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_download_documents.git \
    && git clone https://github.com/gabrieletassoni/thecore_ftp_helpers.git \
    && git clone https://github.com/gabrieletassoni/thecore_ui_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_ui_rails_admin.git

RUN echo "echo 'STUB for explainig how to use thecore console scripts to develop thecore based RoR applications.'" >> ~/.bashrc