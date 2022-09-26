#!/bin/bash -e

CURDIR=$(pwd)
bundle config set path "$CURDIR/vendor/bundle"
bundle config get path
echo "Compiling the default image"
bundle install
SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile
rm -rf tmp/cache/* /tmp/*

export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend:$CI_COMMIT_TAG
echo "Building $IMAGE_TAG_BACKEND"
/usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile"

echo "Compiling custom images"
TARGETDIR="${CI_PROJECT_DIR:-.}/vendor/custombuilds/"
[[ -d "$TARGETDIR" ]] && find "$TARGETDIR" -name Dockerfile | while read -r file; do
    echo "Compiling a custom image for: $file";
    # Looking if thre is a custom script
    DIRNAME=$(dirname "$file")
    PRECOMPILESCRIPT="$DIRNAME/pre-compile.sh"
    [[ -f $PRECOMPILESCRIPT ]] && export `$PRECOMPILESCRIPT`
    # Looking if there are more gems to add
    GEMFILEDELTA="$DIRNAME/Gemfile"
    if [[ -f $GEMFILEDELTA ]] 
    then
        bundle install --gemfile "$GEMFILEDELTA" 
    else
        bundle install
    fi
    SECRET_KEY_BASE=dummy RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile
    rm -rf tmp/cache/* /tmp/*

    export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend-$(basename "$DIRNAME"):$CI_COMMIT_TAG
    echo "Building $IMAGE_TAG_BACKEND"
    /usr/bin/docker-build.sh "$file"
done