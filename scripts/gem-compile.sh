#!/bin/bash -e

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
