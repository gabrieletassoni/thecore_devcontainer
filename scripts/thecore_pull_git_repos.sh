#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e '\e[1mTo Pull thecore related repositories into vendor folder for local editing of the gems:\e[0m\n  1) Please edit, if needed the files in /etc/thecore/repos.conf.d/ by adding the needed repositories (ussually is not needed).\n  2) please run \e[31mthecore_pull_git_repos.sh\e[0m.\n'
exit 0
fi

# Must check if run from the root of a rails app, this must be the case.

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
            git clone "$line"
        fi
    done < "$conffile"
    # Getting all the tags
    for i in *; do if [ -d "$i" ]; then cd "$i"; echo "$i"; git fetch --all --tags --prune; cd ..; fi; done
    cd ../..
done

exit 0