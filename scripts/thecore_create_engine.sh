#!/bin/bash -e

ask_for_name() {
    echo $1
    read NAME
    if [ -z $NAME ]; then
        echo $2
        exit 1
    fi
    echo $NAME
}

ENGINE_NAME=$(ask_for_name "Please provide an engine name in underscore notation:" "Error! No engine name given, bye!")
# Some sanity checks, allow only underscore names
if [[ $ENGINE_NAME == *['!'@#\$%^\&*()\++]* ]]
then
  echo "Error! Engine Name cannot contain special characters other than _"
  exit 2
fi

# Asking for ENGINE specifications
ENGINE_AUTHOR=$(ask_for_name "Please provide Engine's Author:" "Error! No engine Author given, bye!")
ENGINE_EMAIL=$(ask_for_name "Please provide Engine's Author's Email:" "Error! No engine Email given, bye!")
ENGINE_HOMEPAGE=$(ask_for_name "Please provide Engine's Homepage URL:" "Error! No engine Homepage given, bye!")
ENGINE_SUMMARY=$(ask_for_name "Please provide Engine's Summary:" "Error! No engine Summary given, bye!")
ENGINE_DESCRIPTION=$(ask_for_name "Please provide Engine's Extended Description:" "Error! No engine Description given, bye!")
ENGINE_GEM_REPO=$(ask_for_name "Please provide Engine's GEM repository:" "Error! No engine Gem Repository given, bye!")
# Sanity Checks on input variables
EMAIL_REGEX="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
if ! [[ $ENGINE_EMAIL =~ $EMAIL_REGEX ]]
then
  echo "Error! Engine Email must be a valid Email Address"
  exit 3
fi
if ! [[ $ENGINE_HOMEPAGE =~ https?://.* ]]
then
  echo "Error! Engine Homepage must be a valid URL"
  exit 2
fi
if ! [[ $ENGINE_GEM_REPO =~ https?://.* ]]
then
  echo "Error! Engine Gem Repo must be a valid URL"
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
# Remove all spec.add_dependency "thecore_ui_rails_admin", "~> 2.0"
# TODO: ASK for api only gem or UI dependent one and add a dependency on model_driven_api or thecore_ui_rails_admin respectively.

thecoreize_engine.sh

# GIT
# Add gitignore
curl https://www.toptal.com/developers/gitignore/api/osx,macos,ruby,linux,rails,windows,sublimetext,visualstudio,visualstudiocode > .gitignore
# And manage working copy
git init
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