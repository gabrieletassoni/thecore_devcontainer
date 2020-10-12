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


USER vscode
RUN echo "echo 'STUB for explainig how to use thecore console scripts to develop thecore based RoR applications.'" >> ~/.bashrc
