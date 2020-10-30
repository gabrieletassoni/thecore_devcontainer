#!/bin/bash -e
for i in /usr/bin/thecor*
do 
    if [[ ${i} != *"thecore_help"* ]]
    then
        eval "$i --help"
    fi
done

echo -e "\n\e[1mTo show this help again, please run:\e[0m \e[31mthecore_help.sh\e[0m"
exit 0