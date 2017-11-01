
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

    class ThreadedJobQueue
      def initialize
        @queue = Queue.new
        @lock = Mutex.new
      end

      def <<(job)
        @queue << job
      end

      def process(concurrency = 10)
        workers = (1..concurrency).map do
          Thread.new do
            loop do
              fn = @queue.pop
              fn.arity == 1 ? fn.call(@lock) : fn.call
            end
          end
        end
        workers.each { |worker| self << Thread.method(:exit) }
        workers.each { |worker| worker.join }
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

      queue = ThreadedJobQueue.new

      require 'benchmark'

      count = 0
      x = Benchmark.measure("sync time") do
        CookbookMetadata.new(md).files do |url, path|
          count += 1
          queue << lambda do |lock|
            stage = staging_path.join(path)
            FileUtils.mkdir_p(File.dirname(stage))

            raw_file = http_client.streaming_request(url)
            FileUtils.mv(raw_file.path, stage)
          end
        end
        queue.process(10)
        FileUtils.mv(staging_path, install_path)
      end
      p files: count
      puts x
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
      url_path.gsub(/[^[:alnum:]]/, '_')
    end
  end
end

