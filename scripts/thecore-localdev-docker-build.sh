#!/bin/bash -e

cd /workspaces/project/app
bundle update
SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile

cd /etc/thecore/localdockerbuild
docker-compose build -f docker-compose.yml -f docker-compose.build.yml --pull --no-cache backend
docker-compose up -f docker-compose.yml --remove-orphans
