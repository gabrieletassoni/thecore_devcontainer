#!/bin/bash -e

cd /app || exit

echo -e "\e[32mDATABASE_URL $DATABASE_URL\e[0m"

echo -e "\e[32mUser running this script\e[0m"
id

echo -e "\e[32mBundle config get path\e[0m"
bundle config get path

echo -e "\e[32mCreate Database\e[0m"
bundle exec ./bin/rails db:create

echo -e "\e[32mDoing DB migration\e[0m"
if bundle exec ./bin/rails db:migrate
then
    echo -e "\e[32m- Doing DB seed\e[0m"
    if bundle exec ./bin/rails thecore:db:seed
    then
        # Only if all the migrations are ok, run the server
        echo -e "\e[32m- - Everything was ok, starting the rails server\e[0m"
        rm -f tmp/pids/server.pid
        bundle exec ./bin/rails s -p 3000 -b '0.0.0.0'
    fi
fi

exit 0
