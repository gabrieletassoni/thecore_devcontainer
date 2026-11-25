# Ruby and Rails versions no longer float in the images

**Status**: accepted

`Dockerfile.common` started from `ruby:3.3-bookworm` and `Dockerfile.dev` ran `gem install rails:'~> 7.2'`. Both resolved at build time: the Ruby patch and the Rails 7.2 release in an image depended on the day it was built, and an image built before Rails 7.2.4 (a security release) still carried 7.2.3. Nobody could tell which versions an image had without opening it.

**Decision**: `Dockerfile.common` starts from `ruby:3.3.13-bookworm`, the full patch, kept equal to the host apps' `.ruby-version`. `Dockerfile.dev` installs `rails:'~> 7.2.4'`: a minimum, not an exact pin, so a build gets 7.2.4 or a later 7.2.x but never an older one, and never 7.3. Both are raised by hand when the apps move (new `.ruby-version`, new Rails security release).

## Consequences

- Same versions the images already carried when this was decided (Ruby 3.3.13, Rails 7.2.4), so no deployed app changes behaviour.
- A new Ruby patch no longer arrives on its own with the weekly rebuild: bump the `FROM` tag when the apps' `.ruby-version` moves. Debian security updates still do, since Docker rebuilds the `ruby:3.3.13-bookworm` tag on Debian updates and the image runs `apt-get dist-upgrade`.
- The Rails gem in the dev image only serves `rails new` and the like; an app's own Rails comes from its `Gemfile.lock`.
- Covered by `test/version-pins.sh`.

## Amendment (2026-11-25): Ruby 3.3.14

The pin moved to `ruby:3.3.14-bookworm`, with the apps' `.ruby-version` at `ruby-3.3.14`: 3.3.13 carries an RCE, CVE-2026-132825 (Odoo #6261 on Bancolini's GitLab). The `3.3.13` above is the patch this decision started from; the rule, the full patch equal to the apps' `.ruby-version`, is unchanged.

## Amendment (2026-11-25): Rails 8.1

`Dockerfile.dev` installs `rails -v '~> 8.1.4' -v '>= 8.1.4.1'`: the 8.1.4.1 security release or a later 8.1.x, never 8.2. The apps moved to Rails 8.1 on release/3 (Odoo #6087/#6092 on Bancolini's GitLab) and `thecore_generators`' template now writes `rails ~> 8.1.4, >= 8.1.4.1`, so `rails new` in the container produces the same Rails the template asks for. Rails gets its own `gem install`, because RubyGems refuses `--version` together with several gem names. The rule, a minimum patch that never floats to the next minor, is unchanged.
