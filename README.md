# Thecore Backend DevContainer

Build images based on the latest Ruby on Rails needed and adds all the tools mandatory for a proficient **Thecore** Development.

## To build a new version and upload it to docker hub

Please login with `docker login` to docker hub.

Then run the `bin/build` command. This will build the [devcontainer image](https://hub.docker.com/repository/docker/gabrieletassoni/vscode-devcontainers-thecore-frontend) with the latest packages and tools.

This script also creates these images:
- https://hub.docker.com/repository/docker/gabrieletassoni/thecore-frontend
- https://hub.docker.com/repository/docker/gabrieletassoni/thecore-frontend-common

## To create a new major version

- Merge into main the release from which you want to create the next Major version, expect merge conflicts!
- Create a new branch for the new major version from main. Call it **release/4** for example.
- Change the version inside the version file you can find at the root of the project, from 3, to 4, for example.
- Do all the changes needed by your new version.
- Run the `bin/build` command to create the new major version release.
