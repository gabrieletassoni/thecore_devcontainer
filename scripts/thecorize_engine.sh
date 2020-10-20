#!/bin/bash -e

# Sanity Checks
echo "Parameter $1"
if [ -z "$1" ]
then
  echo -e "\e[31mPlease run this script with one parameter.\e[0m"
  exit 1
else
  if ! [[ "API Both GUI" =~ "$1" ]]
  then
    echo -e "\e[31mThe first parameter must be the string API or GUI or Both.\e[0m"
    exit 1
  fi
fi
if ![ -f *.gemspec ]
then
  echo -e "\e[31mThis folder does NOT contain a gemspec file, please run this script INSIDE a rails engine project.\e[0m"
  exit 1
fi

ENGINE_NAME=$(cat *.gemspec|grep -e spec.name -e s.name|sed 's/^ *s.*.name *= *//'|sed 's/["]//g')
ENGINE_NAME_PASCAL_CASE=$(echo "${ENGINE_NAME}" | sed -r 's/(^|_)([a-z])/\U\2/g')

mkdir -p db/migrate app/models/concerns/api app/models/concerns/rails_admin config/initializers config/locales

touch db/migrate/.keep app/models/concerns/api/.keep app/models/concerns/rails_admin/.keep config/initializers/.keep config/locales/.keep

function prepare_for_dependency
{
  sed -i "/spec.files/a \ \ spec.add_dependency '${2}', '~> 2.0'" ${1}.gemspec
  sed -i "/require .${2}./d" lib/${1}.rb
  sed -i "1 s/^/require '${2}'\n/" lib/${1}.rb
}
case $1 in
  "API")
  prepare_for_dependency ${ENGINE_NAME} "model_driven_api"
  ;;
  "GUI")
  prepare_for_dependency ${ENGINE_NAME} "thecore_ui_rails_admin"
  ;;
  "Both")
  prepare_for_dependency ${ENGINE_NAME} "model_driven_api"
  prepare_for_dependency ${ENGINE_NAME} "thecore_ui_rails_admin"
  ;;
esac

# Adding auto migrate to engine.rb
cat > lib/${ENGINE_NAME}/engine.rb << EOL
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

# Replace static VERSION with git tag based version
sed -i 's/^  VERSION =.*/  VERSION = "#{`git describe --tags $(git rev-list --tags --max-count=1)`}"/' lib/$ENGINE_NAME/version.rb

# Adding after initialize
cat > config/initializers/after_initialize_for_${ENGINE_NAME}.rb << EOL
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
cat > config/locales/it.${ENGINE_NAME}.yml << EOL
it:
  active_record:
    models:
    attributes:
EOL

cat > config/locales/en.${ENGINE_NAME}.yml << EOL
en:
  active_record:
    models:
    attributes:
EOL

# Add CI CD Automation
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
