require "cookbook-omnifetch/base"
require "cookbook-omnifetch/metadata_based_installer"

module CookbookOmnifetch
  class ChefServerLocation < BaseLocation

    attr_reader :cookbook_version
    attr_reader :uri

    def initialize(dependency, options = {})
      super
      @cookbook_version = options[:version]
      @http_client = options[:http_client]
      @uri ||= options[:chef_server]
    end

    def cookbook_name
      dependency.name
    end

    def url_path
      "/cookbooks/#{cookbook_name}/#{cookbook_version}"
    end

    def installer
      MetadataBasedInstaller.new(http_client: http_client, url_path: url_path, install_path: install_path)
    end

    def install
      installer.install
    end

    # Determine if this revision is installed.
    #
    # @return [Boolean]
    def installed?
      install_path.exist?
    end

    def http_client
      @http_client
    end

    # The path where this cookbook would live in the store, if it were
    # installed.
    #
    # @return [Pathname, nil]
    def install_path
      @install_path ||= CookbookOmnifetch.storage_path.join(cache_key)
    end

    def lock_data
      { "chef_server" => uri, "version" => cookbook_version }
    end

    def cache_key
      "#{dependency.name}-#{cookbook_version}"
    end

  end
end
