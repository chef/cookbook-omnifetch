
module CookbookOmnifetch

  class MetadataBasedInstaller
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
        :root_files,
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

    attr_reader :http_client
    attr_reader :url_path
    attr_reader :install_path

    def initialize(http_client:, url_path:, install_path:)
      @http_client = http_client
      @url_path = url_path
      @install_path = install_path
    end

    def install
      FileUtils.mkdir_p(staging_root) unless staging_root.exist?
      md = http_client.get(url_path)
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
      Pathname.new(CookbookOmnifetch.cache_path).join(".cache_tmp", "artifactserver")
    end

    def staging_path
      staging_root.join(staging_cache_key)
    end

    def staging_cache_key
      url_path.gsub(/[^[:alnum:]]/, "_")
    end
  end
end
