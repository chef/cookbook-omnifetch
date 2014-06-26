require 'cookbook-omnifetch/base'

# TODO: probably this should be hidden behind DI for http stuff
require 'zlib'
require 'archive/tar/minitar'
require 'tmpdir'

module CookbookOmnifetch

  class ArtifactserverLocation < BaseLocation

    attr_reader :uri
    attr_reader :cookbook_version

    def initialize(dependency, options = {})
      super
      @uri ||= options[:artifactserver]
      @cookbook_version = options[:version]
    end

    def repo_host
      @host ||= URI.parse(uri).host
    end

    def cookbook_name
      dependency.name
    end

    # Determine if this revision is installed.
    #
    # @return [Boolean]
    def installed?
      install_path.exist?
    end

    # Install the given cookbook. Subclasses that implement this method should
    # perform all the installation and validation steps required.
    #
    # @return [void]
    def install
      FileUtils.mkdir_p(cache_root) unless cache_root.exist?

      http = http_client(uri)
      http.streaming_request(nil) do |tempfile|
        tempfile.close
        FileUtils.mv(tempfile.path, cache_path)
      end

      Dir.mktmpdir do |staging_dir|
        Zlib::GzipReader.open(cache_path) do |gz_file|
          tar = Archive::Tar::Minitar::Input.new(gz_file)
          tar.each do |e|
            tar.extract_entry(staging_dir, e)
          end
        end
        staged_cookbook_path = File.join(staging_dir, cookbook_name)
        validate_cached!(staged_cookbook_path)
        FileUtils.mv(staged_cookbook_path, install_path)
      end
    end

    # TODO: DI this.
    def http_client(uri)
      Chef::HTTP::Simple.new(uri)
    end

    def sanitized_version
      cookbook_version
    end

    # The path where this cookbook would live in the store, if it were
    # installed.
    #
    # @return [Pathname, nil]
    def install_path
      @install_path ||= CookbookOmnifetch.storage_path.join(cache_key)
    end

    def cache_key
      "#{dependency.name}-#{cookbook_version}-#{repo_host}"
    end

    # The cached cookbook for this location.
    #
    # @return [CachedCookbook]
    def cached_cookbook
      raise AbstractFunction,
        "#cached_cookbook must be implemented on #{self.class.name}!"
    end

    # The lockfile representation of this location.
    #
    # @return [string]
    def to_lock
      raise AbstractFunction,
        "#to_lock must be implemented on #{self.class.name}!"
    end


    def ==(other)
      raise "TODO"
      other.is_a?(GitLocation) &&
      other.uri == uri &&
      other.branch == branch &&
      other.tag == tag &&
      other.shortref == shortref &&
      other.rel == rel
    end

    def cache_root
      Pathname.new(CookbookOmnifetch.cache_path).join('.cache', 'artifactserver')
    end

    # The path where the pristine tarball is cached
    #
    # @return [Pathname]
    def cache_path
      cache_root.join("#{cache_key}.tgz")
    end

  end
end
