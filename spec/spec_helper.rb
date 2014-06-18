RSpec.configure do |config|

  config.raise_errors_for_deprecations!

  # `expect` should be preferred for new tests or when refactoring old tests,
  # but we're not going to do a "big bang" change at this time.
  config.expect_with :rspec do |c|
    c.syntax = [:expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:expect, :should]
  end

  config.filter_run :focus => true

  config.run_all_when_everything_filtered = true
end

