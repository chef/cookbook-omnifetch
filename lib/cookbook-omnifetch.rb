require "cookbook-omnifetch/version"
require "cookbook-omnifetch/integration"

module CookbookOmnifetch

  # Create a new instance of a Location class given dependency and options.
  # The type of class is determined by the values in the given +options+
  # Hash.
  #
  # If you do not provide an option with a matching location id, +nil+
  # is returned.
  #
  # @example Create a git location
  #   Location.init(dependency, git: 'git://github.com/berkshelf/berkshelf.git')
  #
  # @example Create a GitHub location
  #   Location.init(dependency, github: 'berkshelf/berkshelf')
  #
  # @param [Dependency] dependency
  # @param [Hash] options
  #
  # @return [~BaseLocation, nil]
  def self.init(dependency, options = {})
    if klass = klass_from_options(options)
      klass.new(dependency, options)
    else
      nil
    end
  end

  # Location an executable in the current user's $PATH
  #
  # @return [String, nil]
  #   the path to the executable, or +nil+ if not present
  def self.which(executable)
    if File.file?(executable) && File.executable?(executable)
      executable
    elsif ENV['PATH']
      path = ENV['PATH'].split(File::PATH_SEPARATOR).find do |p|
        File.executable?(File.join(p, executable))
      end
      path && File.expand_path(executable, path)
    end
  end

  # Returns the Integration object which configures Dependency Injection
  # classes for the library.
  # @return [String]
  def self.integration
    @integration ||= Integration.new
  end

  # Yields the Integration object which configures Dependency Injection
  # classes for the library.
  # @yield [String]
  # @see Integration
  def self.configure
    yield integration
  end

  # Returns the filepath to the location where data will be cached.
  # @return [String]
  def self.cache_path
    integration.cache_path
  end

  # Returns an Object (generally a class or module, but that's not required)
  # that responds to the #shell_out method to run an external command. The
  # shell_out method accepts a single string for the command to run, and
  # returns an object that responds to #success?, #stdout and #stderr.
  #
  # Note that this shell_out method should not raise errors automatically.
  #
  # @return [#shell_out]
  def self.shell_out_class
    integration.shell_out_class
  end

  # Returns a pathname object representing the location where cookbooks are
  # cached.
  #
  # NOTE: In the original berks code, this is generally accessed via
  # Berkshelf.cookbook_store.storage_path
  #
  # @return [Pathname]
  def self.storage_path
    integration.storage_path
  end

  class << self
    private

    # Load the correct location from the given options.
    #
    # @return [Class, nil]
    def klass_from_options(options)
      options.each do |key, _|
        id = key.to_s.capitalize

        begin
          return CookbookOmnifetch.const_get("#{id}Location")
        rescue NameError; end
      end

      nil
    end
  end
end
