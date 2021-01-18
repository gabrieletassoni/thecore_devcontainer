#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e '\e[1mTo generate Models for your Engine:\e[0m\n  1) please cd into engine directory\n  2) please run \e[31mthecore_add_model.sh\e[0m\n  3) please follow the wizard adding all the needed models and fields.\n'
exit 0
fi

# thor thecore_generate:models
# Installing dependencies
gem install activesupport

GEMSPEC_FILE="$(find . -name "*.gemspec"|tail -n1)"
GEMNAME=$(basename -- "$GEMSPEC_FILE")
# extension="${GEMNAME##*.}"
GEMNAME="${GEMNAME%.*}"
if [[ -e bin/rails ]]
then
read -rp "Please enter a model declaration (i.e. ModelName title:string:index active:boolean due_at:datetime):" MODEL_DECLARATION
MODEL_ARRAY=($MODEL_DECLARATION) # ex. ModelName title:string:index active:boolean due_at:datetime
MODEL_CAMEL_CASE=${MODEL_ARRAY[0]} # 
MODEL_UNDERSCORE_CASE=$(sed 's/^[[:upper:]]/\L&/;s/[[:upper:]]/\L_&/g' <<< "$MODEL_CAMEL_CASE")
MODEL_UNDERSCORE_PLURAL=$(ruby -e "require 'active_support/inflector'; puts '$MODEL_UNDERSCORE_CASE'.pluralize")
MODEL_FILE_NAME="$MODEL_UNDERSCORE_CASE.rb"
MODEL_FILE_PATH="app/models/$MODEL_FILE_NAME"
rails g model ${MODEL_ARRAY[@]} -s -q -f
echo 'Replace ActiveRecord::Base with ApplicationRecord'
echo "Add rails_admin declaration only in files which are ActiveRecords and don't already have that declaration"
echo 'Thecorize the Model and completing Belongs To Associations'
# Download this entry's template for api and railsadmin
mkdir -p "app/models/concerns/api/" "app/models/concerns/rails_admin/"
# API + Rails Admin Concerns
[[ -e "app/models/concerns/api/$MODEL_FILE_NAME" ]] || cp '/etc/thecore/templates/model_api_concern.tt' "app/models/concerns/api/$MODEL_FILE_NAME"
[[ -e "app/models/concerns/rails_admin/$MODEL_FILE_NAME" ]] || cp '/etc/thecore/templates/model_rails_admin_concern.tt' "app/models/concerns/rails_admin/$MODEL_FILE_NAME"
# Replace in the generated file the templates
sed -i "s/<%= @model_name %>/$MODEL_CAMEL_CASE/g" "app/models/concerns/api/$MODEL_FILE_NAME"
sed -i "s/<%= @model_name %>/$MODEL_CAMEL_CASE/g" "app/models/concerns/rails_admin/$MODEL_FILE_NAME"

# It must be a class and don't have rails_admin declaration
sed -i 's/ActiveRecord::Base/ApplicationRecord/' "$MODEL_FILE_PATH"
# Associations
sed -i '/ApplicationRecord$/a\  # Associations' "$MODEL_FILE_PATH"
# Validations
sed -i '/ApplicationRecord$/a\  # Validations' "$MODEL_FILE_PATH"
# Concerns
sed -i '/ApplicationRecord$/a\  # Concerns' "$MODEL_FILE_PATH"
# If it's UI type only
if grep thecore_ui_rails_admin "$GEMSPEC_FILE"
then
grep "include RailsAdmin::$MODEL_CAMEL_CASE" "$MODEL_FILE_PATH" || sed -i "/ApplicationRecord$/a\  include RailsAdmin::$MODEL_CAMEL_CASE" "$MODEL_FILE_PATH"
fi
# If it's API type only
if grep model_driven_api "$GEMSPEC_FILE"
then
grep "include Api::$MODEL_CAMEL_CASE" "$MODEL_FILE_PATH" || sed -i "/ApplicationRecord$/a\  include Api::$MODEL_CAMEL_CASE" "$MODEL_FILE_PATH"
fi

# TODO: go on with translating line 50 in thecore_generate.thor to bash
echo 'Completing Belongs To Associations:'
sed -i "/^(?!.*inverse_of.*)^ *belongs_to.*$/s/$/, inverse_of: :$MODEL_UNDERSCORE_PLURAL/g" "$MODEL_FILE_PATH"

echo 'Add Has Many Through Associations:'
# Check if the model described in "$MODEL_FILE_PATH" has 2 or more belongs_to
# If it has them, I ask if it's the association model for an Has Many Through
# and give the choice by listing all the belongs_to (user must choose two, 
# maybe I can show all the possible couples if more than two belongs_to are found?)
BELONGS=$(grep -Po 'belongs_to :\K(.+), .+' "$MODEL_FILE_PATH" |cut -d , -f1)
BELONGSARRAY=($BELONGS)
BELONGSNUMBER=${#BELONGS[@]}
if (( $BELONGSNUMBER > 1 ))
then
  echo "$MODEL_FILE_PATH has more than one belongs_to, so it could be an association table for one or more has_many :through associations."
  ASSOCIATIONS=$(ruby -e "pivot='$BELONGS'.split;pivot2=pivot.clone; pivot.each {|elem| pivot2.each{|c| puts elem+'<->'+c if elem != c}; pivot2.shift}")
  for ASSOC in $ASSOCIATIONS
  do
    echo "$MODEL_UNDERSCORE_CASE is the association table between $ASSOC"
    TABLES=$(ruby -e "'$ASSOC'.split('<->').each { |a| puts a }")
    TABLESARY=($TABLES)
    [ ! -f "app/models/${TABLESARY[0]}.rb" ] 
  done
fi

      # I'ts just an approximation, but for now it could work
      association_model = entry.split('.').first.split('/').last
      file = File.join(entry)
      # It must be an activerecord model class
      model_with_belongs_to = File.readlines(file).grep(/^ *belongs_to :.*$/)
      if model_with_belongs_to.size == 2 && yes?("Is #{association_model} an association model for a has_many through relation?", :red)
        # getting both the belongs_to models, find their model files, and add the through to each other
        left_side = model_with_belongs_to.first[/:(.*?),/, 1]
        right_side = model_with_belongs_to.last[/:(.*?),/, 1]
        # This side of the through
        add_has_many_to_model_or_concern name, right_side, left_side, association_model
        add_has_many_to_model_or_concern name, left_side, right_side, association_model
      end

fi