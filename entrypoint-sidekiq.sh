#!/bin/sh

cd /app

bundle exec sidekiq -C config/sidekiq.yml
