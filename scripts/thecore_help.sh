#!/bin/bash -e
for i in /usr/bin/thecor*
do 
    if [[ ${i} != *"thecore_help"* ]]
    then
        eval "$i --help"
    fi
done

echo -e "\e[1mTo git with a single command:\e[0m\n  1) please run \e[31mpush.sh\e[0m\n  2) please answer to the questions posed by the wizard.\n"
echo -e "\e[1mTo trigger a release with a single command:\e[0m\n  1) please run \e[31mrelease.sh\e[0m\n  2) please answer to the questions posed by the wizard.\n"

echo -e "\n\e[1mTo show this help again, please run:\e[0m \e[31mthecore_help.sh\e[0m.\n"
exit 0