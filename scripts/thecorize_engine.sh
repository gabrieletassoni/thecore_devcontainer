#!/bin/bash -e

ENGINE_NAME=$(cat *.gemspec|grep -e spec.name -e s.name|sed 's/^ *s.*.name *= *//'|sed 's/["]//g')
ENGINE_NAME_PASCAL_CASE=$(echo "${ENGINE_NAME}" | sed -r 's/(^|_)([a-z])/\U\2/g')

mkdir -p db/migrate app/models/concerns/api app/models/concerns/rails_admin config/initializers config/locales

touch db/migrate/.keep app/models/concerns/api/.keep app/models/concerns/rails_admin/.keep config/initializers/.keep config/locales/.keep

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
cat > config/initializers/after_initialize_for_${ENGINE_NAME}.rb <<EOL
Rails.application.configure do
  config.after_initialize do
    # Good place for sending concerns about modules
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
