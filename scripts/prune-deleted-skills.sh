#!/bin/bash -e
# `npx skills update` only refreshes skills it already knows about — its own
# "check for deleted skills" step calls the GitHub REST API, which is easily
# rate-limited without a GITHUB_TOKEN/GH_TOKEN and only covers github-sourced
# skills. This script covers the same ground via `git clone` (no REST rate
# limit, no token required for public repos) so orphaned skills get removed
# even when that upstream check silently fails.
#
# Run from a project root that has a skills-lock.json (e.g. from postCreateCommand).

LOCK_FILE="skills-lock.json"

[ -f "$LOCK_FILE" ] || exit 0
command -v jq >/dev/null 2>&1 || { echo "prune-deleted-skills: jq not found, skipping" >&2; exit 0; }
command -v git >/dev/null 2>&1 || { echo "prune-deleted-skills: git not found, skipping" >&2; exit 0; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

declare -A CLONE_DIR
while IFS= read -r source; do
	[ -n "$source" ] || continue
	dir="$WORKDIR/$(echo "$source" | tr '/' '_')"
	if git clone --quiet --depth 1 "https://github.com/${source}.git" "$dir" 2>/dev/null; then
		CLONE_DIR["$source"]="$dir"
	else
		echo "prune-deleted-skills: could not clone ${source}, skipping its skills" >&2
	fi
done < <(jq -r '.skills[] | select(.sourceType == "github") | .source' "$LOCK_FILE" | sort -u)

DELETED=()
while IFS=$'\t' read -r name source skillPath; do
	clone="${CLONE_DIR[$source]:-}"
	[ -n "$clone" ] || continue
	[ -f "$clone/$skillPath" ] || DELETED+=("$name")
done < <(jq -r '.skills | to_entries[] | select(.value.sourceType == "github") | [.key, .value.source, .value.skillPath] | @tsv' "$LOCK_FILE")

if [ "${#DELETED[@]}" -eq 0 ]; then
	echo "prune-deleted-skills: no deleted upstream skills found"
	exit 0
fi

echo "prune-deleted-skills: removing skills deleted upstream: ${DELETED[*]}"
npx skills remove "${DELETED[@]}" --agent '*' -y
