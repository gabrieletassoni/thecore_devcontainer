#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e "\e[1mTo turn an existing Rails engine into a Thecore one (API only):\e[0m\n  1) please cd into engine directory\n  2) please run \e[31m$0 API\e[0m."
echo -e "\e[1mTo turn an existing Rails engine into a Thecore one (GUI only):\e[0m\n  1) please cd into engine directory\n  2) please run \e[31M$0 GUI\e[0m."
echo -e "\e[1mTo turn an existing Rails engine into a Thecore one (API + GUI):\e[0m\n  1) please cd into engine directory\n  2) please run \e[31m$0 Both\e[0m."
echo
exit 0
fi
# Sanity Checks
echo "Parameter $1"
if [[ -z "$1" ]]
then
  echo -e "\e[31mPlease run this script with one parameter.\e[0m"
  exit 1
else
  if ! [[ "API Both GUI" =~ $1 ]]
  then
    echo -e "\e[31mThe first parameter must be the string API or GUI or Both.\e[0m"
    exit 1
  fi
fi
for i in *.gemspec
do
  if ! [ -f "$i" ]
  then
    echo -e "\e[31mThe Folder $(pwd) does NOT contain a gemspec file, please run this script INSIDE a rails engine project.\e[0m"
    exit 1
  fi
done

ENGINE_NAME=$(cat -- *.gemspec|grep -e spec.name -e s.name|sed 's/^ *s.*.name *= *//'|sed 's/["]//g')
ENGINE_NAME_PASCAL_CASE=$(echo "${ENGINE_NAME}" | sed -r 's/(^|_)([a-z])/\U\2/g')

mkdir -p db/migrate app/models/concerns/api app/models/concerns/rails_admin config/initializers config/locales

touch db/migrate/.keep app/models/concerns/api/.keep app/models/concerns/rails_admin/.keep config/initializers/.keep config/locales/.keep

function prepare_for_dependency
{
  sed -i "/spec.files/a \ \ spec.add_dependency '${2}', '~> 2.0'" "${1}".gemspec
  sed -i "/require .${2}./d" lib/"${1}".rb
  sed -i "1 s/^/require '${2}'\n/" lib/"${1}".rb
}
case $1 in
  "API")
  prepare_for_dependency "${ENGINE_NAME}" "model_driven_api"
  ;;
  "GUI")
  prepare_for_dependency "${ENGINE_NAME}" "thecore_ui_rails_admin"
  ;;
  "Both")
  prepare_for_dependency "${ENGINE_NAME}" "model_driven_api"
  prepare_for_dependency "${ENGINE_NAME}" "thecore_ui_rails_admin"
  ;;
esac

# Adding auto migrate to engine.rb
cat > lib/"${ENGINE_NAME}"/engine.rb << EOL
module ${ENGINE_NAME_PASCAL_CASE}
  class Engine < ::Rails::Engine
    initializer "${ENGINE_NAME}.assets.precompile" do |app|    
      # Here you can place the assets provided by this engine in order for them to be precompiled in production and JIT 
      # compiled in development.
      # As an example:
      # app.config.assets.precompile += %w( overrides.css )
      # app.config.assets.precompile += %w( android-chrome-192x192.png )
      # ...
    end
    initializer '${ENGINE_NAME}.add_to_migrations' do |app|
      # Automatically add to main app migrations coming from this engine withiut the need for a rake install
      config.paths['db/migrate'].expanded.each { |expanded_path| app.config.paths['db/migrate'] << expanded_path } unless app.root.to_s.match root.to_s
    end
  end
end
EOL

# Adding auto migrate to engine.rb
if [ ! -f config/initializers/abilities_for_"${ENGINE_NAME}".rb ]
then
cat > config/initializers/abilities_for_"${ENGINE_NAME}".rb << EOL
module Abilities
  class ${ENGINE_NAME_PASCAL_CASE}
    include CanCan::Ability
    def initialize user
      # # By default only admin can do everything
      # # Here are example of usage
      # if user && !user.admin? && user.has_role?(:operator)
      #   # a specific role, brings specific powers
      #   cannot :manage, :all
      #   can :access, :rails_admin # grant access to rails_admin
      # end
      # # Root actions must be declared like this:
      # if user && user.admin?
      #   can :name_of:root_action, :all
      # end
    end
  end
end
EOL
fi

# Replace static VERSION with git tag based version
sed -i 's/^  VERSION =.*/  VERSION = "#{`git describe --tags $(git rev-list --tags --max-count=1)`}"/' lib/"$ENGINE_NAME"/version.rb

# Adding after initialize
cat > config/initializers/after_initialize_for_"${ENGINE_NAME}".rb << EOL
Rails.application.configure do
  config.after_initialize do
    # Good place for sending concerns about modules
    # i.e.
    # ModelName.send(:include, ModelNameConcern)
    # - ModelNameConcern can be defined in config/initializers folder in order to be sure it's automatically loaded during engine bootstrap
  end
end
EOL

# Adding after locales
cat > config/locales/it."${ENGINE_NAME}".yml << EOL
it:
  activerecord:
    models:
    attributes:
EOL

cat > config/locales/en."${ENGINE_NAME}".yml << EOL
en:
  activerecord:
    models:
    attributes:
EOL

# For generating models and the likes, in the local, from gem perspective, add sqlite as dependency
grep sqlite3 Gemfile || echo "gem 'sqlite3'" >> Gemfile

# Add CI CD Automation
# GITLAB
cat > .gitlab-ci.yml << EOL
image: ruby:2.7.1

stages:
    - build

build_gem:
    when: always
    stage: build
    only:
        - tags
    script:
        - gem build *.gemspec
        - gem push
EOL

# GITHUB
mkdir -p .github/workflows/
cat > .github/workflows/gempush.yml << EOL
name: Ruby Gem

on:
  push:
    tags:
      - '*'

jobs:
  build:
    name: Build + Publish
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
    - run: |
        git fetch --unshallow --tags
        echo \$?
        git tag --list
    - name: Set up Ruby 2.6
      uses: actions/setup-ruby@v1
      with:
        ruby-version: 2.6.x

    - name: Publish to RubyGems
      run: |
        mkdir -p \$HOME/.gem
        touch \$HOME/.gem/credentials
        chmod 0600 \$HOME/.gem/credentials
        printf -- "---\n:rubygems_api_key: \${GEM_HOST_API_KEY}\n" > \$HOME/.gem/credentials
        gem build *.gemspec
        gem push *.gem
      env:
        GEM_HOST_API_KEY: \${{secrets.RUBYGEMS_AUTH_TOKEN}}

EOL

exit 0