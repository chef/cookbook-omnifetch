
module Fixtures

  def fixtures_path
    spec_root.join('fixtures')
  end

  def spec_root
    Pathname.new(File.expand_path(File.dirname(__FILE__)))
  end

end

RSpec.configure do |config|

  config.raise_errors_for_deprecations!

  config.include Fixtures

  config.expect_with :rspec do |c|
    c.syntax = [:expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:expect, :should]
  end

  config.filter_run :focus => true

  config.run_all_when_everything_filtered = true
end

