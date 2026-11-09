#!/bin/bash
# Warns on shell login when the project's scaffolded .devcontainer predates the
# Thecore extension version baked into this image (build/thecore-version.txt,
# copied to /etc/thecore/thecore-version.txt by Dockerfile.dev). The scaffold's
# own version is stamped by the "Thecore 3: Setup Devcontainer" command into
# .devcontainer/.thecore-template-version. Run from ~/.bashrc.
#
# The app is mounted at /workspaces/app (thecore samples, App template) or at
# /workspaces/project/backend (the extension's scaffold), and the login shell's
# cwd is not necessarily the app, so the marker is looked up under both layouts.
# THECORE_IMAGE_VERSION_FILE and THECORE_WORKSPACES_DIR exist for the tests
# (test/thecore-motd.sh).

IMAGE_VERSION_FILE="${THECORE_IMAGE_VERSION_FILE:-/etc/thecore/thecore-version.txt}"
WORKSPACES_DIR="${THECORE_WORKSPACES_DIR:-/workspaces}"

MARKER_FILE=""
for candidate in "$WORKSPACES_DIR"/*/.devcontainer/.thecore-template-version \
	"$WORKSPACES_DIR"/*/*/.devcontainer/.thecore-template-version; do
	if [ -f "$candidate" ]; then
		MARKER_FILE="$candidate"
		break
	fi
done

[ -f "$IMAGE_VERSION_FILE" ] && [ -n "$MARKER_FILE" ] || exit 0

IMAGE_VERSION=$(tr -d '[:space:]' < "$IMAGE_VERSION_FILE")
SCAFFOLD_VERSION=$(tr -d '[:space:]' < "$MARKER_FILE")

[ -n "$IMAGE_VERSION" ] && [ -n "$SCAFFOLD_VERSION" ] || exit 0

if dpkg --compare-versions "$SCAFFOLD_VERSION" lt "$IMAGE_VERSION" 2>/dev/null; then
	echo -e "\e[33m⚠ .devcontainer generato con Thecore extension v${SCAFFOLD_VERSION}; questa immagine include v${IMAGE_VERSION}.\e[0m"
	echo -e "\e[33m  Rigeneralo da Command Palette → \"Thecore 3: Setup Devcontainer\" (backup prima la .devcontainer esistente) o confronta i file manualmente.\e[0m"
fi
