require "cookbook-omnifetch"

module Fixtures

  def fixtures_path
    spec_root.join("fixtures")
  end

  def spec_root
    Pathname.new(File.expand_path(File.dirname(__FILE__)))
  end

end

module MockShellOut; end
module MockCachedCookbook; end

RSpec.configure do |config|

  config.raise_errors_for_deprecations!

  config.include Fixtures

  config.expect_with :rspec do |c|
    c.syntax = [:expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = %i{expect should}
  end

  config.filter_run focus: true

  config.run_all_when_everything_filtered = true

  config.before(:suite) do
    CookbookOmnifetch.configure do |c|
      c.cache_path = File.expand_path("~/.berkshelf")
      c.storage_path = Pathname.new(File.expand_path("~/.berkshelf/cookbooks"))
      c.shell_out_class = MockShellOut
      c.cached_cookbook_class = MockCachedCookbook
    end
  end
end
