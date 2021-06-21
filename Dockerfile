FROM ruby:2.7.2

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
        geoip-database \
        libgirepository1.0-dev \
        git-flow \
        graphviz \
    # Update
    && apt-get -y dist-upgrade --no-install-recommends \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

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
RUN useradd -ms /bin/bash vscode
RUN usermod -aG sudo vscode
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER vscode

RUN mkdir ~/.thor
RUN cp /etc/thecore/thecore_generate.thor ~/.thor/a84ebaa152a909f88944fc7354130e94
RUN cp /etc/thecore/thor.yml ~/.thor/thor.yml

EXPOSE 3000

RUN echo 'export PS1="\e[32m\u\e[0m ► \e[96m\W\e[0m [\e[31m\$(git rev-parse --abbrev-ref HEAD)\e[0m:\e[33m\$(git describe --tags --abbrev=0)\e[0m] \$ "'  >> ~/.bashrc

# Add MOTD instructions for scripts provided within this image
RUN echo '/usr/bin/thecore' >> ~/.bashrc
RUN echo 'export APPBIN=/workspaces/project/app/bin'  >> ~/.bashrc
RUN echo 'export CODEBIN=$(find $HOME/.vscode-server/bin/* -maxdepth 1 -mindepth 1 -name bin)'  >> ~/.bashrc
RUN echo 'export PATH=$GEM_HOME/bin:$PATH:$APPBIN:$CODEBIN' >> ~/.bashrc
RUN tail ~/.bashrc

RUN bundle config set path /workspaces/project/app/vendor/bundle

WORKDIR /workspaces/project
