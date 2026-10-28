# Ruby and Rails versions no longer float in the images

**Status**: accepted

`Dockerfile.common` started from `ruby:3.3-bookworm` and `Dockerfile.dev` ran `gem install rails:'~> 7.2'`. Both resolved at build time: the Ruby patch and the Rails 7.2 release in an image depended on the day it was built, and an image built before Rails 7.2.4 (a security release) still carried 7.2.3. Nobody could tell which versions an image had without opening it.

**Decision**: `Dockerfile.common` starts from `ruby:3.3.13-bookworm`, the full patch, kept equal to the host apps' `.ruby-version`. `Dockerfile.dev` installs `rails:'~> 7.2.4'`: a minimum, not an exact pin, so a build gets 7.2.4 or a later 7.2.x but never an older one, and never 7.3. Both are raised by hand when the apps move (new `.ruby-version`, new Rails security release).

## Consequences

- Same versions the images already carried when this was decided (Ruby 3.3.13, Rails 7.2.4), so no deployed app changes behaviour.
- A new Ruby patch no longer arrives on its own with the weekly rebuild: bump the `FROM` tag when the apps' `.ruby-version` moves. Debian security updates still do, since Docker rebuilds the `ruby:3.3.13-bookworm` tag on Debian updates and the image runs `apt-get dist-upgrade`.
- The Rails gem in the dev image only serves `rails new` and the like; an app's own Rails comes from its `Gemfile.lock`.
- Covered by `test/version-pins.sh`.
