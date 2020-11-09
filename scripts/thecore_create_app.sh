#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e '\e[1mTo create a Thecore APP:\e[0m\n  1) please run \e[31mthecore_create_app.sh\e[0m\n  2) please answer to the questions posed by the wizard'
exit 0
fi

# Functions
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

echo "Please enter app's name:" 
read -r FULLNAME
if [[ "$FULLNAME" =~ ^[a-z0-9_]+$ ]]
then
    echo "Creating a generic app" 
    if [[ -e "$FULLNAME" ]]
    then
        echo "ERROR! The directory already exists, please think about another name and re-run this script." 
        exit 1
    fi

    # TODO: Check on template necessity can this wizard be completely driven only 
    # by this shell script?
    #  -m 'https://raw.githubusercontent.com/gabrieletassoni/thecore_setup_templates/master/new_thecore_app.rb' 

    # Create arguments (optional and mandatory)
    args=( )
    # Ask for type of database needed
    echo "Which database will be used by the app?"
    echo -e "\e[31mBe sure to have the correct libraries (drivers/clients) installed in the Operative System.\e[0m"
    OPTIONS=("mysql" "postgresql" "sqlite3" "oracle" "frontbase" "ibm_db" "sqlserver" "jdbcmysql" "jdbcsqlite3" "jdbcpostgresql" "jdbc")
    choose
    DB_TYPE=$CHOICE
    args+=( --database "$DB_TYPE" )

    # Ask for local or remote DB
    echo "Is the database local or remote to this server?"
    OPTIONS=("local" "remote")
    choose
    DB_LOCATION=$CHOICE

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
    rails new "$FULLNAME" "${args[@]}"

    yesno "Is the Database already existing?"
    if [[ $CHOICE == "yes" ]]
    then
        echo "Please provide the connection string for the existing Database."
        echo "The format may look like these:"
        echo "- postgres://localhost/thecore_db?pool=5"
        echo "- mysql2://root:password@127.0.0.1/thecore_db?pool=5"
        echo "- sqlite3::memory:"
        echo -e "\e[31mThe database must be already up and running and reachable by this installation.\e[0m"
        STOPLOOP=false
        while $STOPLOOP
        do
            read -r
            yesno "Is the connection string $REPLY correct?"
            if [[ $CHOICE == "yes" ]]
            then
                DB_CONNECTION_STRING_TEST="${REPLY}"
                DB_CONNECTION_STRING_DEV="${REPLY}"
                DB_CONNECTION_STRING_PROD="${REPLY}"
                STOPLOOP=true
            fi
        done
    else
        echo "For local postgresql Databases I can try to setup the DB for you. Otherwise you need to create it by yourself and provide the connection string restarting this installation script again."
        if [[ $DB_LOCATION == "local" ]] && [[ $DB_TYPE == "postgresql" ]]
        then
            echo "Please provide sudo password."
            sudo id
            # CLEANUPS
            sudo -u postgres -- dropdb --if-exists "${FULLNAME}_development" # Dev
            sudo -u postgres -- dropdb --if-exists "${FULLNAME}_test" # Test
            sudo -u postgres -- dropdb --if-exists "${FULLNAME}" # Prod
            sudo -u postgres -- dropuser --if-exists "${FULLNAME}"
            # CREATIONS
            sudo -u postgres createuser -d "${FULLNAME}"
            sudo -u postgres psql -c "alter user ${FULLNAME} with encrypted password '${FULLNAME}';"
            sudo -u postgres createdb -O "${FULLNAME}" "${FULLNAME}" 
            sudo -u postgres createdb -O "${FULLNAME}" "${FULLNAME}_development" 
            sudo -u postgres createdb -O "${FULLNAME}" "${FULLNAME}_test"

            DB_CONNECTION_STRING_TEST="postgres://${FULLNAME}:${FULLNAME}@localhost/${FULLNAME}_test?pool=5"
            DB_CONNECTION_STRING_DEV="postgres://${FULLNAME}:${FULLNAME}@localhost/${FULLNAME}_development?pool=5"
            DB_CONNECTION_STRING_PROD="postgres://${FULLNAME}:${FULLNAME}@localhost/${FULLNAME}?pool=5"     
        fi
    fi

    cat <<EOF | tee "${FULLNAME}/config/database.yml"
development:
  url: ${DB_CONNECTION_STRING_DEV}

test:
  url: ${DB_CONNECTION_STRING_TEST}

production:
  url: ${DB_CONNECTION_STRING_PROD}
EOF
  
    echo "${FULLNAME}" > "${FULLNAME}/.ruby-gemset"
    cd "$FULLNAME"

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
    OPTIONS=("setup" "provide" "none of the above, go on without adding a private repository")
    choose
    if [[ $CHOICE == "setup" ]]
    then
        STOPLOOP=false
        while $STOPLOOP
        do
            while [[ "$GEMURL" == '' ]]
            do
                read -rp "Please provide the gem server URL (i.e. https://www.alchemic.it/gems): " GEMURL
            done 

            while [[ "$USERNAME" == '' ]]
            do
                read -rp "Please provide username for $GEMURL gems repository: " USERNAME
            done 

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
    elif [[ $CHOICE == "provide" ]]
    then
        # Just add in the Gemfile
        STOPLOOP=false
        while $STOPLOOP
        do
            echo "Write here the URL of the private GEMs repository"
            read -r
            yesno "Is GEMs URL $REPLY correct?"
            if [[ $CHOICE == "yes" ]]
            then
                echo "source '$REPLY'" >> Gemfile
            fi
            yesno "Would you like to add more private gems repositories?"
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
        STOPLOOP=false
        while $STOPLOOP
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
    rails active_storage:install
    rails action_text:install
    yarn install
    rails db:migrate
    
    # Add gitignore
    curl https://www.toptal.com/developers/gitignore/api/osx,macos,ruby,linux,rails,windows,sublimetext,visualstudio,visualstudiocode > .gitignore

    git init
    git add . -A
    git commit -a -m "Initial Git"
    yesno "Would you like to add a remote git repository?"
    if [[ $CHOICE == "no" ]]
    then
        STOPLOOP=false
        while $STOPLOOP
        do
            read -r
            yesno "Is the connection string $REPLY correct?"
            if [[ $CHOICE == "yes" ]]
            then
                git remote origin add "${REPLY}"
                STOPLOOP=true
            fi
        done
    fi
    cd ..
else
    echo "ERROR! The name can only contain lowercase letters, - and _" 
    exit 1
fi

echo "New Thecore App: ${FULLNAME} created."

exit 0