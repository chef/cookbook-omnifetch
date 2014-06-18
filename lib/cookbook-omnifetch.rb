require "cookbook-omnifetch/version"

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
