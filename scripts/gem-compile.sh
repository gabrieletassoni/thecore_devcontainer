#!/bin/bash -e

echo Getting the version from the gemspec file
version=$(grep -oP 'VERSION = "\K[^"]+' lib/*/version.rb | awk -F'.' '{print $1"."$2"."$3}')
echo Obtain the list of local tags
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
    git config --local user.email "${GITLAB_EMAIL:-noreply@alchemic.it}"
    git config --local user.name "${GITLAB_USER_NAME:-AlchemicIT}"
    git tag -a $version -m "Version $version"
    git push --tags "$GITLAB_OAUTH_TARGET"
    gem build *.gemspec
    if $GITLAB_GEM_REPO_TARGET
    then
        gem install geminabox
        gem inabox *.gem -g "$GITLAB_GEM_REPO_TARGET"
    else
        gem push
    fi
fi