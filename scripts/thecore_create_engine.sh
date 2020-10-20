#!/bin/bash -e

# Sanity Checks
if [ -d .git ]
then
  echo -e "\e[31mThis folder contains a GIT setup, please run this script outside a project.\e[0m"
  exit 1
fi
if [ -f Gemfile ]
then
  echo -e "\e[31mThis folder contains a Gemfile, please run this script outside a rails app project.\e[0m"
  exit 1
fi
if [ -f *.gemspec ]
then
  echo -e "\e[31mThis folder contains a gemspec file, please run this script outside a rails engine project.\e[0m"
  exit 1
fi

function ask_for_name # VARNAME prompt
{
  while [ -z "${!1}" ]
  do
    read -p "$2: " $1
  done
}

ask_for_name ENGINE_NAME "Please provide an engine name in underscore notation"
# Some sanity checks, allow only underscore names
if [[ $ENGINE_NAME == *['!'@#\$%^\&*()\++]* ]]
then
  echo -e "\e[31mError! Engine Name cannot contain special characters other than _\e[0m"
  exit 2
fi

# Asking for ENGINE specifications
ask_for_name ENGINE_AUTHOR "Please provide Engine's Author"
ask_for_name ENGINE_EMAIL "Please provide Engine's Author's Email"
ask_for_name ENGINE_HOMEPAGE "Please provide Engine's Homepage URL"
ask_for_name ENGINE_SUMMARY "Please provide Engine's Summary"
ask_for_name ENGINE_DESCRIPTION "Please provide Engine's Extended Description"
ask_for_name ENGINE_GEM_REPO "Please provide Engine's GEM repository"
# ASK for api only gem or UI dependent one and add a dependency on model_driven_api or thecore_ui_rails_admin respectively.
PS3="Please select the type of engine you are creating, select it by specifying element's number from the list above:"
TYPE=Both
select T in API GUI Both
do
  echo "Selected ${T}"
  if ! [ -z "$T" ]
  then
    TYPE=T
    break
  fi
done
# Sanity Checks on input variables
EMAIL_REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
if ! [[ $ENGINE_EMAIL =~ $EMAIL_REGEX ]]
then
  echo -e "\e[31mError! Engine Email must be a valid Email Address.\e[0m"
  exit 3
fi
if ! [[ $ENGINE_HOMEPAGE =~ https?://.* ]]
then
  echo -e "\e[31mError! Engine Homepage must be a valid URL.\e[0m"
  exit 2
fi
if ! [[ $ENGINE_GEM_REPO =~ https?://.* ]]
then
  echo -e "\e[31mError! Engine Gem Repo must be a valid URL.\e[0m"
  exit 4
fi

rails plugin new $ENGINE_NAME -fG --full

cd $ENGINE_NAME

# Setup the gemspec file
sed -i 's/^  spec.authors =.*/  spec.authors = ["$ENGINE_AUTHOR"]/' ${ENGINE_NAME}.gemspec
sed -i 's/^  spec.email =.*/  spec.email = ["$ENGINE_EMAIL"]/' ${ENGINE_NAME}.gemspec
sed -i 's/^  spec.homepage =.*/  spec.homepage = "$ENGINE_HOMEPAGE"/' ${ENGINE_NAME}.gemspec
sed -i 's/^  spec.summary =.*/  spec.summary = "$ENGINE_SUMMARY"/' ${ENGINE_NAME}.gemspec
sed -i 's/^  spec.description =.*/  spec.description = "$ENGINE_DESCRIPTION"/' ${ENGINE_NAME}.gemspec
sed -i 's/^    spec.metadata\["allowed_push_host"\] =.*/    spec.metadata\["allowed_push_host"\] = "$ENGINE_GEM_REPO"/' ${ENGINE_NAME}.gemspec
# Remove all spec.add_dependency 
sed -i '/add_dependency/d' ${ENGINE_NAME}.gemspec
sed -i '/add_development_dependency/d' ${ENGINE_NAME}.gemspec

thecorize_engine.sh ${TYPE}

# GIT
# Add gitignore
curl https://www.toptal.com/developers/gitignore/api/osx,macos,ruby,linux,rails,windows,sublimetext,visualstudio,visualstudiocode > .gitignore
# And manage working copy
git init
git config user.name "$ENGINE_AUTHOR"
git config user.email "$ENGINE_EMAIL"
git add . -A
git commit -a -m "Initial git"
echo "Please add a git repository URI if you like (empty string to add nothing):"
read URI
if [ -z $URI ]; then
    exit 0
fi

git remote add origin $URL

cd ..

exit 0