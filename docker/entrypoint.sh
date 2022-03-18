#!/bin/sh

cd /app

if ! /app/bin/rails runner "ActiveRecord::Base.connection rescue exit 1"
then
    # Fare solo la prima volta
    /app/bin/rails db:create >log/latest-startup.log 2>&1
fi

if /app/bin/rails db:migrate >>log/latest-startup.log 2>&1
then 
    if /app/bin/rails thecore:db:seed >>log/latest-startup.log 2>&1
    then
        # Only if all the migrations are ok, run the server
        rm -f tmp/pids/server.pid
        /app/bin/rails s -p 3000 -b '0.0.0.0'
    fi
fi

exit 0
