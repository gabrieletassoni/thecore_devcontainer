#!/bin/bash -e

bundle config set path vendor/bundle
bundle config get path
bundle update
SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile
rm -rf tmp/cache/* /tmp/*
