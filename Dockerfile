# Build Arguments
# ARG VARIANT=2
# FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${VARIANT}
FROM ruby:2.7.2
# FROM mcr.microsoft.com/vscode/devcontainers/base:buster

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | (OUT=$(apt-key add - 2>&1) || echo $OUT) \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-key adv --refresh-keys --keyserver keyserver.ubuntu.com \
    && apt-get update && apt-get -y install \
        poppler-utils \
        libvips-tools \
        libvips-dev \
        imagemagick \
        docker-compose \
        software-properties-common \
        build-essential \
        freetds-dev \
        libcups2-dev \
        yarn \
        sudo \
        apt-utils \
        git \
        openssh-client \
        gnupg2 \
        iproute2 \
        procps \
        lsof \
        htop \
        net-tools \
        psmisc \
        wget \
        rsync \
        ca-certificates \
        unzip \
        zip \
        nano \
        vim-tiny \
        less \
        jq \
        lsb-release \
        apt-transport-https \
        dialog \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu[0-9][0-9] \
        liblttng-ust0 \
        libstdc++6 \
        zlib1g \
        locales \
        sudo \
        ncdu \
        man-db \
        strace \
        libssl1.1 \
        gridsite-clients \
    # Update
    && apt-get -y dist-upgrade --no-install-recommends \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Installing the base thecore gems
# Databases
# RUN gem install \
#     pg \
#     mysql2 \
#     sqlite3 \
#     mongoid \
#     bson_ext \
#     tiny_tds \
#     activerecord-sqlserver-adapter
# General Use GEMs
# RUN gem install \
#     rails:6.0.3.4 \
#     erubi:1.10.0 \
#     turbolinks-source \
#     turbolinks \
#     web-console \
#     webdrivers \
#     webpacker:4.3.0 \
#     spring \
#     spring-watcher-listen \
#     sass-rails \
#     selenium-webdriver \
#     rack-proxy \
#     puma:4.3.7 \
#     rb-fsevent \
#     rb-inotify \
#     listen \
#     jbuilder \
#     fugit \
#     regexp_parser \
#     xpath \
#     capybara \
#     childprocess \
#     byebug \
#     bindex \
#     msgpack \
#     bootsnap \
#     public_suffix \
#     addressable \
#     zeitwerk \
#     geminabox \
#     thor \
#     haml
# Thecore GEMs
# RUN gem install \
#     model_driven_api:2.3.1 \
#     rails_admin_selectize:2.0.4 \
#     thecore_auth_commons:2.2.9 \
#     thecore_backend_commons:2.3.1 \
#     thecore_background_jobs:2.0.2 \
#     thecore_dataentry_commons:2.0.5 \
#     thecore_download_documents:2.0.2 \
#     thecore_ftp_helpers:2.1.2 \
#     thecore_print_commons:2.0.3 \
#     thecore_print_with_template:2.0.2 \
#     thecore_ui_commons:2.2.1 \
#     thecore_ui_rails_admin:2.2.4 \
#     thecore_mssql_importer_common:2.0.1
# RUN gem update

# Add to the container thecore specific scripts
COPY scripts/ /usr/bin/
COPY bin/increment_version.sh /usr/bin/increment_version.sh
RUN mkdir -p /etc/thecore/templates
COPY templates /etc/thecore/templates
COPY thor_definitions/ /etc/thecore/
RUN mkdir -p /etc/thecore/repos.conf.d
COPY repos /etc/thecore/repos.conf.d

# Creating the git clones of thecore gems.
# Useful to have them already inside the dev environment if the need to customize them arises.
# Otherwise the gem installed ones will suffice to the needs of thecore development.
# WORKDIR /workspaces
RUN useradd -ms /bin/bash vscode
RUN usermod -aG sudo vscode
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
# RUN mkdir -p /workspaces/thecore
# RUN chown -R vscode /workspaces
USER vscode
# WORKDIR /workspaces/thecore
# RUN git clone https://github.com/gabrieletassoni/model_driven_api.git \
#     && git clone https://github.com/gabrieletassoni/rails_admin_selectize.git \
#     && git clone https://github.com/gabrieletassoni/thecore_auth_commons.git \
#     && git clone https://github.com/gabrieletassoni/thecore_backend_commons.git \
#     && git clone https://github.com/gabrieletassoni/thecore_background_jobs.git \
#     && git clone https://github.com/gabrieletassoni/thecore_dataentry_commons.git \
#     && git clone https://github.com/gabrieletassoni/thecore_download_documents.git \
#     && git clone https://github.com/gabrieletassoni/thecore_ftp_helpers.git \
#     && git clone https://github.com/gabrieletassoni/thecore_ui_commons.git \
#     && git clone https://github.com/gabrieletassoni/thecore_ui_rails_admin.git \
#     && git clone https://github.com/gabrieletassoni/thecore_print_commons.git \
#     && git clone https://github.com/gabrieletassoni/thecore_print_with_template.git \
#     && git clone https://github.com/gabrieletassoni/thecore_mssql_importer_commmon.git

# Getting all the tags
# RUN for i in *; do if [ -d "$i" ]; then cd "$i"; echo "$i"; git fetch --all --tags --prune; cd ..; fi; done

RUN mkdir ~/.thor
RUN cp /etc/thecore/thecore_generate.thor ~/.thor/a84ebaa152a909f88944fc7354130e94
RUN cp /etc/thecore/thor.yml ~/.thor/thor.yml

EXPOSE 3000

# Add MOTD instructions for scripts provided within this image
RUN echo '/usr/bin/thecore' >> ~/.bashrc
RUN echo 'export APPBIN=$(find /workspaces/*/ -maxdepth 1 -mindepth 1 -name bin)'  >> ~/.bashrc
RUN echo 'export CODEBIN=$(find $HOME/.vscode-server/bin/* -maxdepth 1 -mindepth 1 -name bin)'  >> ~/.bashrc
RUN echo 'export PATH=$GEM_HOME/bin:$PATH:$APPBIN:$CODEBIN' >> ~/.bashrc
RUN tail ~/.bashrc

RUN bundle config set path /workspaces/project/app/vendor/bundle

WORKDIR /workspaces/project
