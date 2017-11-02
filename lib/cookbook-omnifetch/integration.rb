require "cookbook-omnifetch/exceptions"

module CookbookOmnifetch

  class MissingConfiguration < OmnifetchError; end

  class NullValue; end

  class Integration

    def self.configurables
      @configurables ||= []
    end

    def self.configurable(name)
      configurables << name

      attr_writer name

      define_method(name) do
        value = instance_variable_get("@#{name}".to_sym)
        case value
        when NullValue
          raise MissingConfiguration, "`#{name}` is not configured"
        when Proc
          value.call
        else
          value
        end
      end
    end

    configurable :cache_path
    configurable :storage_path
    configurable :shell_out_class
    configurable :cached_cookbook_class

    # Number of threads to use when downloading from a Chef Server. See
    # commentary in cookbook_omnifetch.rb
    configurable :chef_server_download_concurrency

    def initialize
      self.class.configurables.each do |configurable|
        instance_variable_set("@#{configurable}".to_sym, NullValue.new)
      end
      @chef_server_download_concurrency = 1
    end

  end
end
