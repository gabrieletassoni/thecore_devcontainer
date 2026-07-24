#!/bin/bash
# Warns on shell login when the project's scaffolded .devcontainer predates the
# Thecore extension version baked into this image (build/thecore-version.txt,
# copied to /etc/thecore/thecore-version.txt by Dockerfile.dev). The scaffold's
# own version is stamped by the "Thecore 3: Setup Devcontainer" command into
# .devcontainer/.thecore-template-version. Sourced from ~/.bashrc.

IMAGE_VERSION_FILE="/etc/thecore/thecore-version.txt"
MARKER_FILE="/workspaces/project/.devcontainer/.thecore-template-version"

[ -f "$IMAGE_VERSION_FILE" ] && [ -f "$MARKER_FILE" ] || exit 0

IMAGE_VERSION=$(tr -d '[:space:]' < "$IMAGE_VERSION_FILE")
SCAFFOLD_VERSION=$(tr -d '[:space:]' < "$MARKER_FILE")

[ -n "$IMAGE_VERSION" ] && [ -n "$SCAFFOLD_VERSION" ] || exit 0

if dpkg --compare-versions "$SCAFFOLD_VERSION" lt "$IMAGE_VERSION" 2>/dev/null; then
	echo -e "\e[33m⚠ .devcontainer generato con Thecore extension v${SCAFFOLD_VERSION}; questa immagine include v${IMAGE_VERSION}.\e[0m"
	echo -e "\e[33m  Rigeneralo da Command Palette → \"Thecore 3: Setup Devcontainer\" (backup prima la .devcontainer esistente) o confronta i file manualmente.\e[0m"
fi
