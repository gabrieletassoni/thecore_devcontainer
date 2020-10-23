# Build Arguments
ARG VARIANT=2
FROM mcr.microsoft.com/vscode/devcontainers/ruby:0-${VARIANT}

RUN apt-get update && apt-get -y install \
        freetds-dev \
        libcups2-dev \
    # Clean up
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts/

# Installing the base thecore gems
RUN gem install rails:6.0.3.4 \
    # Databases
    pg \
    mysql2 \
    sqlite3 \
    mongoid \
    bson_ext \
    tiny_tds \
    activerecord-sqlserver-adapter \
    # End Databases
    # General Use GEMs
    geminabox \
    # Thecore GEMs
    thecore_auth_commons:2.2.8 \
    thecore_backend_commons:2.3.0 \
    thecore_background_jobs:2.0.1 \
    thecore_ftp_helpers:2.0.6 \
    thecore_ui_commons:2.2.0 \
    thecore_ui_rails_admin:2.2.1 \
    thecore_dataentry_commons:2.0.4 \
    thecore_print_commons:2.0.1 \
    thecore_print_with_template:2.0.0

# Creating the git clones of thecore gems.
# Useful to have them already inside the dev environment if the need to customize them arises.
# Otherwise the gem installed ones will suffice to the needs of thecore development.
WORKDIR /workspaces
RUN mkdir -p thecore
RUN chown -R vscode /workspaces/thecore
USER vscode
WORKDIR /workspaces/thecore
RUN git clone https://github.com/gabrieletassoni/model_driven_api.git \
    && git clone https://github.com/gabrieletassoni/rails_admin_selectize.git \
    && git clone https://github.com/gabrieletassoni/thecore_auth_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_backend_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_background_jobs.git \
    && git clone https://github.com/gabrieletassoni/thecore_dataentry_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_download_documents.git \
    && git clone https://github.com/gabrieletassoni/thecore_ftp_helpers.git \
    && git clone https://github.com/gabrieletassoni/thecore_ui_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_ui_rails_admin.git \
    && git clone https://github.com/gabrieletassoni/thecore_print_commons.git \
    && git clone https://github.com/gabrieletassoni/thecore_print_with_template.git

# Add to the container thecore specific scripts
COPY scripts/ /usr/bin/
COPY templates /etc/thecore/
COPY thor_definitions/ /etc/thecore/

RUN mkdir ~/.thor
RUN cp /etc/thecore/thecore_generate.thor ~/.thor/a84ebaa152a909f88944fc7354130e94
RUN cp /etc/thecore/thor.yml ~/.thor/thor.yml

# Add MOTD instructions for scripts provided within this image
RUN echo "echo -e '\e[1mTo create a Thecore Engine:\e[0m\n  1) please run \e[31mthecore_create_engine.sh\e[0m\n  2) please answer to the questions posed by the wizard'" >> ~/.bashrc
RUN echo "echo -e '\e[1mTo turn an existing Rails engine into a Thecore one (API only):\e[0m\n  1) please cd into engine directory\n  2) please run \e[31mthecorize_engine.sh API\e[0m'" >> ~/.bashrc
RUN echo "echo -e '\e[1mTo turn an existing Rails engine into a Thecore one (GUI only):\e[0m\n  1) please cd into engine directory\n  2) please run \e[31mthecorize_engine.sh GUI\e[0m'" >> ~/.bashrc
RUN echo "echo -e '\e[1mTo turn an existing Rails engine into a Thecore one (API + GUI):\e[0m\n  1) please cd into engine directory\n  2) please run \e[31mthecorize_engine.sh Both\e[0m'" >> ~/.bashrc
RUN echo "echo -e '\e[1mTo generate Models for your Engine:\e[0m\n  1) please cd into engine directory\n  2) please run \e[31mthecore_add_model.sh\e[0m\n  3) please follow the wizard adding all the needed models and fields.'" >> ~/.bashrc
