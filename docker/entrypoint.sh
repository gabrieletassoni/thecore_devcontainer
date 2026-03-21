#!/bin/bash -e

cd /app || exit 1

echo -e "\e[32mDATABASE_URL: $DATABASE_URL\e[0m"
echo -e "\e[32mUser running this script\e[0m"
id
echo -e "\e[32mBundle config path\e[0m"
bundle config get path

echo -e "\e[32mCreating database...\e[0m"
bundle exec ./bin/rails db:create

echo -e "\e[32mRunning migrations...\e[0m"
bundle exec ./bin/rails db:migrate

echo -e "\e[32mSeeding database...\e[0m"
bundle exec ./bin/rails thecore:db:seed

echo -e "\e[32mClobbering assets...\e[0m"
bundle exec ./bin/rails assets:clobber

echo -e "\e[32mPrecompiling assets...\e[0m"
bundle exec ./bin/rails assets:precompile

echo -e "\e[32mStarting Rails server...\e[0m"
rm -f tmp/pids/server.pid
exec bundle exec ./bin/rails s -p 3000 -b '0.0.0.0'
