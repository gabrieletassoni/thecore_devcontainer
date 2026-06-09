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

# Guard: seed runs only when explicitly requested.
# thecore:db:seed is idempotent but can be slow; opt in with SEED_ON_START=true.
if [[ "${SEED_ON_START:-false}" == "true" ]]; then
    echo -e "\e[32mSeeding database...\e[0m"
    bundle exec ./bin/rails thecore:db:seed
fi

# Guard: asset compilation runs on first start or when forced.
# Skipped on restarts when public/assets already exists, saving 2–5 minutes.
# Force recompilation with RECOMPILE_ASSETS=true.
if [[ "${RECOMPILE_ASSETS:-false}" == "true" ]] || [[ ! -d public/assets ]]; then
    echo -e "\e[32mClobbering assets...\e[0m"
    bundle exec ./bin/rails assets:clobber

    echo -e "\e[32mPrecompiling assets...\e[0m"
    bundle exec ./bin/rails assets:precompile
else
    echo -e "\e[32mAssets already compiled, skipping (set RECOMPILE_ASSETS=true to force).\e[0m"
fi

echo -e "\e[32mStarting Rails server...\e[0m"
rm -f tmp/pids/server.pid
exec bundle exec ./bin/rails s -p 3000 -b '0.0.0.0'
