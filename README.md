# CookbookOmnifetch

`CookbookOmnifetch` provides library code for fetching Chef cookbooks
from an artifact server (usually https://supermarket.chef.io),
git/github, a local path, or a chef-server to a local cache for
developement.

## Installation

Add this line to your application's Gemfile:

    gem 'cookbook-omnifetch'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cookbook-omnifetch

## Usage

#### Inject Dependencies and Configure

Cookbook Omnifetch is designed to work with utilities from both the
Berkshelf and Chef Software ecosystems, so you have to configure it
before you can use it. In ChefDK, we do this:

```ruby
# Configure CookbookOmnifetch's dependency injection settings to use our classes and config.
CookbookOmnifetch.configure do |c|
  c.cache_path = File.expand_path('~/.chefdk/cache')
  c.storage_path = Pathname.new(File.expand_path('~/.chefdk/cache/cookbooks'))
  c.shell_out_class = ChefDK::ShellOut
  c.cached_cookbook_class = ChefDK::CookbookMetadata
end
```

#### Fetching Cookbooks

To download a cookbook:

```ruby
fetcher = CookbookOmnifetch.init(dependency, source_options)
fetcher.install
```

To specify the cookbook you want, you give CookbookOmnifetch a
dependency object that responds to `#name` and `#version_constraint`,
e.g.:

```ruby
require 'semverse'

Dependency = Struct.new(:name, :version_constraint)

my_dep = Dependency.new("apache2", Semverse::Constraint.new("~> 1.0"))
```

The source options for the cookbook are given as a Hash; the keys and
values vary based on the kind of storage location. As with Bundler's
`gem` options, one key specifies the type of upstream service for the
cookbook while other keys specify other options specific to that type.
For example:

```ruby
CookbookOmnifetch.init(dependency, artifact_server: "https://supermarket.chef.io/api/v1/cookbooks/apache2/versions/3.0.1/download")
CookbookOmnifetch.init(dependency, git: "git@github.com:svanzoest/apache2-cookbook.git", tag: "v3.0.1")
CookbookOmnifetch.init(dependency, github: "svanzoest/apache2-cookbook", tag: "v3.0.1")
CookbookOmnifetch.init(dependency, path: "~/chef-cookbooks/apache2")
```

## Contributing

For information on contributing to this project, see https://github.com/chef/chef/blob/master/CONTRIBUTING.md

After that:

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -asm 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Thanks

This code was initially extracted from Berkshelf. Thanks to the
Berkshelf core teams and contributors.

