require 'cookbook-omnifetch/base'

module CookbookOmnifetch
  class CookbookMetadata

    FILE_TYPES = [
      :resources,
      :providers,
      :recipes,
      :definitions,
      :libraries,
      :attributes,
      :files,
      :templates,
      :root_files
    ].freeze

    def initialize(metadata)
      @metadata = metadata
    end

    def files(&block)
      FILE_TYPES.each do |type|
        next unless @metadata.has_key?(type.to_s)

        @metadata[type.to_s].each do |file|
          yield file["url"], file["path"]
        end
      end
    end
  end

  class ChefserverLocation < BaseLocation

    attr_reader :cookbook_version

    def initialize(dependency, options = {})
      super
      @cookbook_version = options[:version]
      @http_client = options[:http_client]
      @uri ||= options[:artifactserver]
    end

    def repo_host
      @host ||= URI.parse(uri).host
    end

    def cookbook_name
      dependency.name
    end

    def install
      FileUtils.mkdir_p(staging_root) unless staging_root.exist?
      md = http_client.get("/cookbooks/#{cookbook_name}/#{cookbook_version}")
      CookbookMetadata.new(md).files do |url, path|
        stage = staging_path.join(path)
        FileUtils.mkdir_p(File.dirname(stage))

        http_client.streaming_request(url) do |tempfile|
          tempfile.close
          FileUtils.mv(tempfile.path, stage)
        end
      end
      FileUtils.mv(staging_path, install_path)
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

    def cache_key
      "#{dependency.name}-#{cookbook_version}"
    end

    # The path where tarballs are downloaded to and unzipped.  On certain platforms
    # you have a better chance of getting an atomic move if your temporary working
    # directory is on the same device/volume as the  destination.  To support this,
    # we use a staging directory located under the cache path under the rather mild
    # assumption that everything under the cache path is going to be on one device.
    #
    # Do not create anything under this directory that isn't randomly named and
    # remember to release your files once you are done.
    #
    # @return [Pathname]
    def staging_root
      Pathname.new(CookbookOmnifetch.cache_path).join('.cache_tmp', 'artifactserver')
    end

    def staging_path
      staging_root.join(cache_key)
    end
  end
end
