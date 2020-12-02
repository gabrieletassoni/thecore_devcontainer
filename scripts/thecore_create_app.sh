#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e '\e[1mTo create a Thecore APP:\e[0m\n  1) please run \e[31mthecore_create_app.sh\e[0m\n  2) please answer to the questions posed by the wizard'
exit 0
fi

# Functions
tc() { set "${*,,}" ; echo "${*^}" ; }
choose () {
    echo -e "\e[33mPlease type the number of the choice.\e[0m"
    select CHOICE in "${OPTIONS[@]}"; do
        # $opt being empty signals invalid input.
        [[ -n $CHOICE ]] || { echo "Invalid option, please try again typing the number of the choice." >&2; continue; }
        break # a valid choice was made, exit the prompt.
    done
}

yesno () {
    echo "$1"
    OPTIONS=("yes" "no")
    choose
}

FULLNAME="$(basename "$(pwd)")"
yesno "The WebApp will be called $FULLNAME, is this ok?"
[[ $CHOICE == "no" ]] && read -p "Please provide an alternative name: " -r FULLNAME
pattern='^[a-z0-9_-]+$'
if [[ "$FULLNAME" =~ $pattern ]]
then
    # Create arguments (optional and mandatory)
    args=( )
    # Ask for type of database needed
    echo "Which database adapter will be used by the app?"
    echo -e "\e[31mBe sure to have the correct libraries (drivers/clients) installed in the Operative System.\e[0m"
    OPTIONS=(mysql postgresql sqlite3 oracle frontbase ibm_db sqlserver jdbcmysql jdbcsqlite3 jdbcpostgresql jdbc)
    choose
    DB_TYPE=$CHOICE
    args+=( --database "$DB_TYPE" )

    # Ask for type of aplication needed
    echo "Which kind of Thecore App would you like to create?"
    OPTIONS=("api" "backend" "both")
    choose
    APPLICATION_TYPE="$CHOICE"
    if [[ "$APPLICATION_TYPE" == "api" ]]
    then
        args+=( --api )
    fi

    # Actually run the selected Thecore application type
    rails new . "${args[@]}"

    if [[ "$DB_TYPE" == "sqlite3" ]]
    then
        DB_CONNECTION_STRING_TEST="${DB_TYPE}:${FULLNAME}_test"
        DB_CONNECTION_STRING_DEV="${DB_TYPE}:${FULLNAME}_dev"
        DB_CONNECTION_STRING_PROD="${DB_TYPE}:${FULLNAME}_prod"
    else
        case $DB_TYPE in
            mysql)
                DB_TYPE=mysql2
                ;;
            postgresql)
                DB_TYPE=postgres
                ;;
        esac
        STOPLOOP=true
        while $STOPLOOP
        do
            read -p "Please provide the ADDRESS of the DB: " -r ADDRESS
            yesno "Is the ADDRESS $ADDRESS correct?"
            [[ $CHOICE == "yes" ]] && STOPLOOP=false
        done
        STOPLOOP=true
        while $STOPLOOP
        do
            read -p "Please provide the PORT of the DB: " -r PORT
            yesno "Is the ADDRESS $PORT correct?"
            [[ $CHOICE == "yes" ]] && STOPLOOP=false
        done
        STOPLOOP=true
        while $STOPLOOP
        do
            read -p "Please provide the USER of the DB: " -r USER
            yesno "Is the ADDRESS $USER correct?"
            [[ $CHOICE == "yes" ]] && STOPLOOP=false
        done
        STOPLOOP=true
        while $STOPLOOP
        do
            read -p "Please provide the PASS of the DB: " -r PASS
            yesno "Is the ADDRESS $PASS correct?"
            [[ $CHOICE == "yes" ]] && STOPLOOP=false
        done

        DB_CONNECTION_STRING_TEST="${DB_TYPE}://${USER}:${PASS}@${ADDRESS}:${PORT}/${FULLNAME}_test?pool=5"
        DB_CONNECTION_STRING_DEV="${DB_TYPE}://${USER}:${PASS}@${ADDRESS}:${PORT}/${FULLNAME}_dev?pool=5"
        DB_CONNECTION_STRING_PROD="${DB_TYPE}://${USER}:${PASS}@${ADDRESS}:${PORT}/${FULLNAME}_prod?pool=5"
    fi
    touch "config/database.yml"
    cat <<EOF | tee "config/database.yml"
development:
  url: ${DB_CONNECTION_STRING_DEV}

test:
  url: ${DB_CONNECTION_STRING_TEST}

production:
  url: ${DB_CONNECTION_STRING_PROD}
EOF
  
    cat <<EOF | tee "app/assets/stylesheets/overrides.scss"
// Please remove this file if you'd like to override it in an engine.
// You can override these UI settings:

// \$primary: #1f4068;

// \$background: lighten(\$primary, 51%);
// \$shadows: darken(\$primary, 10%);

// \$text: darken(\$primary, 40%);
// \$text-highlight: lighten(\$text, 80%);

// \$link: \$text;
// \$link-highlight: lighten(\$link, 10%);

// \$element: \$primary;
// \$element-text: lighten(\$element, 40%);
// \$element-text-highlight: lighten(\$element-text, 10%);
// \$element-border: darken(\$element, 10%);

// \$neutral: #706f6f;
// \$success: #37BC9B;
// \$info: #3BAFDA;
// \$danger: #E9573F;
// \$warning: #F6BB42;
EOF

    echo "${FULLNAME}" > ".ruby-gemset"

    # Add Thecore base gems
    if [[ $APPLICATION_TYPE == "api" ]]
    then
        echo "gem 'model_driven_api', '~> 2.0', require: 'model_driven_api'" >> Gemfile
    elif [[ $APPLICATION_TYPE == "backend" ]]
    then
        echo "gem 'thecore_ui_rails_admin', '~> 2.0', require: 'thecore_ui_rails_admin'" >> Gemfile
    elif [[ $APPLICATION_TYPE == "both" ]]
    then
        echo "gem 'model_driven_api', '~> 2.0', require: 'model_driven_api'" >> Gemfile
        echo "gem 'thecore_ui_rails_admin', '~> 2.0', require: 'thecore_ui_rails_admin'" >> Gemfile
    fi

    # Private GEM Repo
    echo "Would you like to setup a private gem repository or provide an existing one?"
    OPTIONS=("setup" "don't want to setup a private GEMs repository, go on without adding one")
    choose
    if [[ "$CHOICE" == "setup" ]]
    then
        STOPLOOP="false"
        while [[ "$STOPLOOP" == "false" ]]
        do
            echo "1"
            while [[ "$GEMURL" == '' ]]
            do
                read -rp "Please provide the gem server URL (i.e. https://gems.alchemic.it): " GEMURL
            done 

            echo "2"
            while [[ "$USERNAME" == '' ]]
            do
                read -rp "Please provide username for $GEMURL gems repository: " USERNAME
            done 

            echo "3"
            while [[ "$PASSWORD" == '' ]]
            do
                read -rp "Please provide the password for $USERNAME: " PASSWORD
            done 

            CREDENTIALS="$(urlencode "$USERNAME"):$(urlencode "$PASSWORD")"
            gem sources -a "${GEMURL/:\/\//:\/\/$CREDENTIALS@}"
            bundle config "$GEMURL" "$CREDENTIALS"

            yesno "Would you like to setup more private gems repositories?"
            if [[ $CHOICE == "no" ]]
            then
                STOPLOOP=true
            fi
        done
    fi

    # Asking for more gems
    yesno "Do you want to add more gems to the App?"
    if [[ $CHOICE == "yes" ]]
    then
        STOPLOOP="false"
        while [[ "$STOPLOOP" == "false" ]]
        do
            echo "Please add the name and the semver of the gem."
            echo "For example: thecore_background_jobs 2.0"
            echo "this will be translated to gem 'thecore_background_jobs', '~> 2.0', require: 'thecore_background_jobs'"
            read -r GEMNAME VERSION
            yesno "Are the gem name and version correct? $GEMNAME $VERSION"
            if [[ $CHOICE == "yes" ]]
            then
                echo "gem '$GEMNAME', '~> $VERSION', require: '$GEMNAME'" >> Gemfile
            fi
            yesno "Would you like to add more gems?"
            if [[ $CHOICE == "no" ]]
            then
                STOPLOOP=true
            fi
        done
    fi

    bundle install
    rails webpacker:install
    rails active_storage:install
    rails action_text:install
    yarn install
    rails db:create
    rails g migration ChangeThecoreAppName
    APPNAMEFILE=$(find db/migrate -maxdepth 1 -mindepth 1 -name "*_change_thecore_app_name.rb")
    sed -i "/def change/a \ \ \ \ Settings.app_name = '$(tc "${FULLNAME//[-_]/ }")'" "$APPNAMEFILE"
    rails db:migrate
    
    # Add gitignore
    curl https://www.toptal.com/developers/gitignore/api/osx,macos,ruby,linux,rails,windows,sublimetext,visualstudio,visualstudiocode > .gitignore
    echo ".passwords" >> .gitignore

    git init
    git add . -A
    git commit -a -m "Initial Git"
    yesno "Would you like to add a remote git repository?"
    if [[ $CHOICE == "yes" ]]
    then
        STOPLOOP="false"
        while [[ "$STOPLOOP" == "false" ]]
        do
            read -r -p "Please provide a git repository URL: " GITREPOURL
            yesno "Is the connection string $GITREPOURL correct?"
            if [[ $CHOICE == "yes" ]]
            then
                git remote add origin "${GITREPOURL}"
                git push --set-upstream origin master
                STOPLOOP=true
            fi
        done
    fi
else
    echo -e "\e[31m\e[1mERROR"'!'"\e[0m The name can only contain lowercase letters, numbers, - and _: \e[31m\e[1mplease rename\e[0m\e[31m this project's folder to match the given constraint\e[0m." 
    exit 1
fi

echo "New Thecore App: ${FULLNAME} created."

exit 0