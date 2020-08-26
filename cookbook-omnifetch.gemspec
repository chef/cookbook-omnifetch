lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cookbook-omnifetch/version"

Gem::Specification.new do |spec|
  spec.name          = "cookbook-omnifetch"
  spec.version       = CookbookOmnifetch::VERSION
  spec.authors       = [
    "Jamie Winsor",
    "Josiah Kiehl",
    "Michael Ivey",
    "Justin Campbell",
    "Seth Vargo",
    "Daniel DeLeo",
  ]
  spec.email = [
    "jamie@vialstudios.com",
    "jkiehl@riotgames.com",
    "michael.ivey@riotgames.com",
    "justin@justincampbell.me",
    "sethvargo@gmail.com",
    "dan@chef.io",
  ]
  spec.summary       = %q{Library code to fetch Chef cookbooks from a variety of sources to a local cache}
  spec.homepage      = "https://github.com/chef/cookbook-omnifetch"
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = ">= 2.5"

  spec.files         = `git ls-files -z`.split("\x0").grep(/LICENSE|^lib/)
  spec.require_paths = ["lib"]

  spec.add_dependency "mixlib-archive", ">= 0.4", "< 2.0"
end
