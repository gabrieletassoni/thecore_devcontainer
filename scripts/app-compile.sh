#!/bin/bash -e

echo Getting the version from version file
version=$(tr -d '\n' < version)
echo Obtain the list of local tags
git config --global --add safe.directory $CI_PROJECT_DIR
local_tags=$(git tag)
echo $local_tags
echo Obtain the list of remote tags
remote_tags=$(git ls-remote --tags origin | awk '{print $2}' | awk -F '/' '{print $3}')
echo $remote_tags
echo Iterate over local tags
for tag in $local_tags; do
    echo Verify if tag $tag has a corresponding remote tag
    if ! echo "$remote_tags" | grep -q "^$tag$"; then
        echo This tag does not exist on the remote: $tag
        git tag -d "$tag"
        echo "Tag $tag eliminata."
    fi
done
echo If version $version already exists, do nothing
echo otherwise, create a new tag, push it and build the gem
if echo $remote_tags | grep -q $version;
then
    echo "Version $version already exists"
else
    echo "Version $version does not exist"
    echo "Setting up git user and email"
    git config --local user.email "${GITLAB_EMAIL:-noreply@alchemic.it}"
    git config --local user.name "${GITLAB_USER_NAME:-AlchemicIT}"
    echo "Creating tag $version"
    git tag -a $version -m "Version $version"
    echo "Pushing tag $version"
    if [ -z "$GITLAB_OAUTH_TARGET" ]
    then
        echo "GITLAB_OAUTH_TARGET does not exists. Pushing to origin."
        git push --tags
    else
        echo "Pushing to $GITLAB_OAUTH_TARGET"
        git push --tags "$GITLAB_OAUTH_TARGET"
    fi

    # A new tag has been added to the repository, so we need to compile the images
    CURDIR=$(pwd)
    bundle config set path "$CURDIR/vendor/bundle"
    bundle config get path
    echo "Compiling the default image"
    bundle install
        
    # echo "Compiling the default assets (/ and /backend)"
    # SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile
    # SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production DATABASE_URL=nulldb:fake RAILS_RELATIVE_URL_ROOT=/ ASSETS_PREFIX=/assets ./bin/rails --trace assets:precompile
    # SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production DATABASE_URL=nulldb:fake RAILS_RELATIVE_URL_ROOT=/backend ASSETS_PREFIX=/backend/assets ./bin/rails --trace assets:precompile

    rm -rf tmp/cache/* /tmp/*

    export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend:$version
    echo "Building $IMAGE_TAG_BACKEND"
    /usr/bin/docker-build.sh "/etc/thecore/docker/Dockerfile" $version

    # echo "Compiling custom images"
    # TARGETDIR="${CI_PROJECT_DIR:-.}/vendor/custombuilds/"
    # [[ -d "$TARGETDIR" ]] && find "$TARGETDIR" -name Dockerfile | while read -r file; do
    #     echo "Compiling a custom image for: $file";
    #     # Looking if thre is a custom script
    #     DIRNAME=$(dirname "$file")
    #     PRECOMPILESCRIPT="$DIRNAME/pre-compile.sh"
    #     [[ -f $PRECOMPILESCRIPT ]] && export `$PRECOMPILESCRIPT`
    #     # Looking if there are more gems to add
    #     GEMFILEDELTA="$DIRNAME/Gemfile"
    #     [[ -f $GEMFILEDELTA ]] && bundle install --gemfile "$GEMFILEDELTA"
        
    #     # SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production DATABASE_URL=nulldb:fake ./bin/rails --trace assets:precompile
    #     # SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production DATABASE_URL=nulldb:fake RAILS_RELATIVE_URL_ROOT=/ ASSETS_PREFIX=/assets ./bin/rails --trace assets:precompile
    #     # SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production DATABASE_URL=nulldb:fake RAILS_RELATIVE_URL_ROOT=/backend ASSETS_PREFIX=/backend/assets ./bin/rails --trace assets:precompile
        
    #     rm -rf tmp/cache/* /tmp/*

    #     export IMAGE_TAG_BACKEND=${CI_REGISTRY_IMAGE}/backend-$(basename "$DIRNAME"):$version
    #     echo "Building $IMAGE_TAG_BACKEND"
    #     /usr/bin/docker-build.sh "$file" $version
    # done
fi