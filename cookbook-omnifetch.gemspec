# coding: utf-8
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
    "dan@getchef.com",
  ]
  spec.summary       = %q{Library code to fetch Chef cookbooks from a variety of sources to a local cache}
  spec.homepage      = "http://www.getchef.com/"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_dependency "mixlib-archive", ">= 0.4", "< 2.0"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"

end
