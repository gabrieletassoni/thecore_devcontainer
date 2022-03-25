#!/bin/bash -e

[[ -z "$BANCOLINI_GEMS_CREDENTIALS" ]] && exit 1

bundle config set path vendor/bundle
bundle config get path
bundle update
SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile
rm -rf tmp/cache/* /tmp/*
