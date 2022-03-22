#!/bin/sh

cd /app || exit

bundle exec sidekiq -C config/sidekiq.yml
