#!/bin/bash -e

if [[ $1 == "--help" ]]
then
echo -e '\e[1mTo generate Models for your Engine:\e[0m\n  1) please cd into engine directory\n  2) please run \e[31mthecore_add_model.sh\e[0m\n  3) please follow the wizard adding all the needed models and fields.'
exit 0
fi

thor thecore_generate:models