#!/bin/sh

cd /app

if ! bundle exec rails runner "ActiveRecord::Base.connection rescue exit 1"
then
    # Fare solo la prima volta
    bundle exec rails db:create >log/latest-startup.log 2>&1
fi

if bundle exec rails db:migrate >>log/latest-startup.log 2>&1
then 
    if bundle exec rails thecore:db:seed >>log/latest-startup.log 2>&1
    then
        # Only if all the migrations are ok, run the server
        rm -f tmp/pids/server.pid
        bundle exec rails s -p 3000 -b '0.0.0.0'
    fi
fi

exit 0
