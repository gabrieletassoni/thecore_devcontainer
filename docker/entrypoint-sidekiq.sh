#!/bin/sh

cd /app || exit

echo "DATABASE_URL $DATABASE_URL"

bundle exec sidekiq -C config/sidekiq.yml
