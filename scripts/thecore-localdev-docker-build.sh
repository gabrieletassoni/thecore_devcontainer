#!/bin/bash -e

sudo docker version
sudo docker-compose version

cd /workspaces/project/app
bundle update
SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile

cd /etc/thecore/localdockerbuild

export IMAGE_TAG_BACKEND="backenddev:latest"
export CI_PROJECT_DIR=/workspaces/project/app

sudo -E docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    build --pull --no-cache backend

sudo -E docker-compose up --remove-orphans