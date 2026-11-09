#!/bin/bash
# Prints the folder of the app mounted in this dev container, for ~/.bashrc
# (Dockerfile.dev): APPBIN, BUNDLE_APP_CONFIG and the prompt's version use it.
#
# The app is mounted at /workspaces/app (thecore samples, "Create an App") or at
# /workspaces/project/backend (the extension's scaffold), so it is the first
# folder with a Gemfile under /workspaces/*/, then /workspaces/*/*/ - the same
# lookup order thecore-motd.sh uses for its marker. With none found (nothing
# mounted yet) it prints /workspaces/project/backend, the old fixed path.
# THECORE_WORKSPACES_DIR exists for the tests (test/thecore-app-dir.sh).

WORKSPACES_DIR="${THECORE_WORKSPACES_DIR:-/workspaces}"

for candidate in "$WORKSPACES_DIR"/*/Gemfile "$WORKSPACES_DIR"/*/*/Gemfile; do
	if [ -f "$candidate" ]; then
		dirname "$candidate"
		exit 0
	fi
done

echo "$WORKSPACES_DIR/project/backend"
