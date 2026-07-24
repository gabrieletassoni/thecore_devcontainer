#!/bin/bash -e
# Pre-build hook: package VS Code extensions found in submodules/ into build/thecore.vsix.
# Run by bin/build-image before the docker build step.

mkdir -p build
rm -f build/*.vsix

for d in submodules/*/; do
    if [[ -f "${d}extension.js" ]]; then
        echo "Found VS Code extension in ${d}, packaging..."
        (
            cd "$d"
            yarn install --frozen-lockfile
            vsce package
            mv ./*.vsix ../../build/thecore.vsix
            node -p "require('./package.json').version" > ../../build/thecore-version.txt
        )
        echo "Packaged ${d} -> build/thecore.vsix"
    fi
done
