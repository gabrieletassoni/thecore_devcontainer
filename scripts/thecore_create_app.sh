#!/bin/bash -e

# VEDERE: https://github.com/gabrieletassoni/thecore_setup_templates/blob/master/bin/create_thecore_app
# C'è già quasi tutto
# in generale in https://github.com/gabrieletassoni/thecore_setup_templates ci sono parecchi spunti interessanti per gli 
# script che ci aiutano a creare app thecore based

# Chiedere il nome della webapp
# Controllare che sia un nome coerente (no spazi, no dash, etc)
# Chiedere se si vuole un'applicazione UI o solo API
# Se solo APi aggiunge in automatico la dipendenza a model_driven_api ultima versione disponibile sul server gem
# es, nel Gemfile: gem 'model_driven_api', '~> 2.0', require: 'model_driven_api' # , path: "../thecore/model_driven_api" 
