require 'cookbook-omnifetch/exceptions'

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

    def initialize
      self.class.configurables.each do |configurable|
        instance_variable_set("@#{configurable}".to_sym, NullValue.new)
      end
    end

  end
end
