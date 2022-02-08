#!/bin/sh

cd /app || exit

if ! bundle exec rails runner "ActiveRecord::Base.connection rescue exit 1"
then
    # Fare solo la prima volta
    bundle exec rails db:create >log/latest-startup.log 2>&1
fi

bundle exec rails db:migrate >>log/latest-startup.log 2>&1
bundle exec rails thecore:db:seed >>log/latest-startup.log 2>&1

rm -f tmp/pids/server.pid
bundle exec rails s -p 3000 -b '0.0.0.0'

exit 0
