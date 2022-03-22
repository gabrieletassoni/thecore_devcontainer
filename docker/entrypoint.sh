#!/bin/sh

cd /app || exit

echo "DATABASE_URL $DATABASE_URL"

if ! /app/bin/rails runner "ActiveRecord::Base.connection rescue exit 1"
then
    # Fare solo la prima volta
    /app/bin/rails db:create
fi

if /app/bin/rails db:migrate
then 
    if /app/bin/rails thecore:db:seed
    then
        # Only if all the migrations are ok, run the server
        rm -f tmp/pids/server.pid
        /app/bin/rails s -p 3000 -b '0.0.0.0'
    fi
fi

exit 0
