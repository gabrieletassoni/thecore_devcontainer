#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e "\e[1mTo Pull thecore related repositories into vendor folder for local editing of the gems:\e[0m\n  1) Please edit, if needed the files in /etc/thecore/repos.conf.d/ by adding the needed repositories (usually is un-needed).\n  2) please run \e[31m$0\e[0m\n"
exit 0
fi

# Trap failures to get also the line number of the failure
set -eE -o functrace
failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

# Must check if run from the root of a rails app, this must be the case.
if [ -f Gemfile ]
then
    # Managing the git submodules for vscode compatibiity (git repos under other git repos are not managed by vscode otherwise)
    rm -f .submodules
    touch .submodules

    ROOTDIR=$(pwd)

    for conffile in /etc/thecore/repos.conf.d/*.conf
    do
        CURDIR=$(basename "$conffile" .conf)
        mkdir -p "vendor/$CURDIR"
        cd "vendor/$CURDIR"
        # clone all the repos
        while read -r line
        do 
            if [ -n "$line" ]
            then
                MODULE=$(basename "$line" .git)
                # Rebuilding the submodules
                echo -e "[submodule \"$MODULE\"]\n    path = vendor/$CURDIR/$MODULE\n    url = $line\n" >> "$ROOTDIR/.submodules"
                [ -d "$MODULE" ] || git clone "$line"
            fi
        done < "$conffile"
        # Getting all the tags
        for i in *; do if [ -d "$i" ]; then cd "$i"; echo "$i"; git pull; git fetch --all --tags --prune; cd ..; fi; done
        cd ../..
    done
else
    echo "ERROR! Must be run inside root dir of your Ruby on Rails app (the dir in which is present a Gemfile)."
    exit 1
fi

exit 0