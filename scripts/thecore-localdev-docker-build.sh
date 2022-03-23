#!/bin/bash -e

docker version
docker-compose version

cd /workspaces/project/app
bundle update
SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile

cd /etc/thecore/localdockerbuild
docker-compose \
    -f docker-compose.yml \
    -f docker-compose.build.yml \
    build --pull --no-cache backend
docker-compose up --remove-orphans
