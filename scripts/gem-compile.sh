#!/bin/bash -e

echo Getting the version from the gemspec file
version=$(find ./lib -name version.rb -exec grep -oP 'VERSION = "\K[^"]+' {} \; | awk -F'.' '{print $1"."$2"."$3}')
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
    echo "Building gem"
    gem build *.gemspec
    echo "Pushing gem"
    if [ -z "$GITLAB_GEM_REPO_TARGET" ]
    then
        echo "GITLAB_GEM_REPO_TARGET does not exists. Pushing to rubygems.org."
        gem push
    else
        # This needs also the env var GEM_HOST_API_KEY to be set with the credentials from a valid user.
        echo "Pushing to $GITLAB_GEM_REPO_TARGET"
        gem push --host "$GITLAB_GEM_REPO_TARGET" *.gem
    fi
fi