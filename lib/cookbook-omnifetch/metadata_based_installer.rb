require_relative "threaded_job_queue"

module CookbookOmnifetch

  class MetadataBasedInstaller
    class CookbookMetadata

      FILE_TYPES = %i{
        resources
        providers
        recipes
        definitions
        libraries
        attributes
        files
        templates
        root_files
        all_files
      }.freeze

      def initialize(metadata)
        @metadata = metadata
      end

      def files(&block)
        FILE_TYPES.each do |type|
          next unless @metadata.key?(type.to_s)

          @metadata[type.to_s].each do |file|
            yield file["url"], file["path"]
          end
        end
      end
    end

    attr_reader :http_client
    attr_reader :url_path
    attr_reader :install_path
    attr_reader :slug

    def initialize(http_client:, url_path:, install_path:)
      @http_client = http_client
      @url_path = url_path
      @install_path = install_path
      @slug = Kernel.rand(1_000_000_000).to_s
    end

    def install
      FileUtils.rm_rf(staging_path) # ensure we have a clean dir, just in case
      FileUtils.mkdir_p(staging_root) unless staging_root.exist?
      md = http_client.get(url_path)

      queue = ThreadedJobQueue.new

      CookbookMetadata.new(md).files do |url, path|
        stage = staging_path.join(path)
        FileUtils.mkdir_p(File.dirname(stage))

        queue << lambda do |_lock|
          http_client.streaming_request(url) do |tempfile|
            tempfile.close
            FileUtils.mv(tempfile.path, stage)
          end
        end
      end

      queue.process(CookbookOmnifetch.chef_server_download_concurrency)

      FileUtils.mv(staging_path, install_path)
    end

    # The path where files are downloaded to.  On certain platforms you have a
    # better chance of getting an atomic move if your temporary working
    # directory is on the same device/volume as the  destination.  To support
    # this, we use a staging directory located under the cache path under the
    # rather mild assumption that everything under the cache path is going to
    # be on one device.
    #
    # @return [Pathname]
    def staging_root
      Pathname.new(CookbookOmnifetch.cache_path).join(".cache_tmp", "metadata-installer")
    end

    def staging_path
      staging_root.join(staging_cache_key)
    end

    # Convert the URL to a safe name for a file and append our random slug.
    # This helps us avoid colliding in the case that there are multiple
    # processes installing the same cookbook at the same time.
    def staging_cache_key
      "#{url_path.gsub(/[^[:alnum:]]/, "_")}_#{slug}"
    end
  end
end
