require "tmpdir" unless defined?(Dir.mktmpdir)
require_relative "../cookbook-omnifetch"
require_relative "base"
require_relative "exceptions"

module CookbookOmnifetch
  class GitLocation < BaseLocation
    attr_reader :uri
    attr_reader :branch
    attr_reader :tag
    attr_reader :ref
    attr_reader :revision
    attr_reader :rel

    def initialize(dependency, options = {})
      super

      @uri      = options[:git]
      @branch   = options[:branch]
      @tag      = options[:tag]
      @ref      = options[:ref]
      @revision = options[:revision]
      @rel      = options[:rel]

      # The revision to parse
      @rev_parse = options[:ref] || options[:branch] || options[:tag] || "main"
    end

    # @see BaseLoation#installed?
    def installed?
      (!!revision) && install_path.exist?
    end

    # Install this git cookbook into the cookbook store. This method leverages
    # a cached git copy and a scratch directory to prevent bad cookbooks from
    # making their way into the cookbook store.
    #
    # @see BaseLocation#install
    def install
      scratch_path = Pathname.new(Dir.mktmpdir)

      if cached?
        Dir.chdir(cache_path) do
          git %{fetch --force --tags #{uri} "refs/heads/*:refs/heads/*"}
        end
      else
        git %{clone #{uri} "#{cache_path}" --bare --no-hardlinks}
      end

      Dir.chdir(cache_path) do
        @revision ||= git %{rev-parse #{@rev_parse}}
      end

      # Clone into a scratch directory for validations
      git %{clone --no-checkout "#{cache_path}" "#{scratch_path}"}

      # Make sure the scratch directory is up-to-date and account for rel paths
      Dir.chdir(scratch_path) do
        git %{fetch --force --tags "#{cache_path}"}
        git %{reset --hard #{@revision}}

        if rel
          git %{filter-branch --subdirectory-filter "#{rel}" --force}
        end
      end

      # Validate the scratched path is a valid cookbook
      validate_cached!(scratch_path)

      # If we got this far, we should copy
      FileUtils.rm_rf(install_path) if install_path.exist?
      FileUtils.cp_r(scratch_path, install_path)

      # Remove the git history
      FileUtils.rm_rf(File.join(install_path, ".git"))

      install_path.chmod(0777 & ~File.umask)
    ensure
      # Ensure the scratch directory is cleaned up
      FileUtils.rm_rf(scratch_path) if scratch_path
    end

    # @see BaseLocation#cached_cookbook
    def cached_cookbook
      if installed?
        @cached_cookbook ||= CookbookOmnifetch.cached_cookbook_class.from_path(install_path)
      else
        nil
      end
    end

    def ==(other)
      other.is_a?(GitLocation) &&
        other.uri == uri &&
        other.branch == branch &&
        other.tag == tag &&
        other.shortref == shortref &&
        other.rel == rel
    end

    def to_s
      info = tag || branch || shortref || @rev_parse

      if rel
        "#{uri} (at #{info}/#{rel})"
      else
        "#{uri} (at #{info})"
      end
    end

    def lock_data
      out = {}
      out["git"] = uri
      out["revision"] = revision
      out["ref"] = shortref if shortref
      out["branch"] = branch if branch
      out["tag"] = tag if tag
      out["rel"] = rel if rel
      out
    end

    def to_lock
      out =  "    git: #{uri}\n"
      out << "    revision: #{revision}\n"
      out << "    ref: #{shortref}\n"  if shortref
      out << "    branch: #{branch}\n" if branch
      out << "    tag: #{tag}\n"       if tag
      out << "    rel: #{rel}\n"       if rel
      out
    end

    # The path where this cookbook would live in the store, if it were
    # installed.
    #
    # @return [Pathname, nil]
    def install_path
      CookbookOmnifetch.storage_path
        .join(cache_key)
    end

    def cache_key
      "#{dependency.name}-#{revision}"
    end

    protected

    # The short ref (if one was given).
    #
    # @return [String, nil]
    def shortref
      ref && ref[0...7]
    end

    private

    # Perform a git command.
    #
    # @param [String] command
    #   the command to run
    # @param [Boolean] error
    #   whether to raise error if the command fails
    #
    # @raise [String]
    #   the +$stdout+ from the command
    def git(command, error = true)
      unless CookbookOmnifetch.which("git") || CookbookOmnifetch.which("git.exe") || CookbookOmnifetch.which("git.bat")
        raise GitNotInstalled.new
      end

      response = CookbookOmnifetch.shell_out_class.shell_out(%{git #{command}})

      if error && !response.success?
        raise GitCommandError.new(command, cache_path, response.stderr)
      end

      response.stdout.strip
    end

    # Determine if this git repo has already been downloaded.
    #
    # @return [Boolean]
    def cached?
      cache_path.exist?
    end

    # The path where this git repository is cached.
    #
    # @return [Pathname]
    def cache_path
      Pathname.new(CookbookOmnifetch.cache_path)
        .join(".cache", "git", Digest::SHA1.hexdigest(uri))
    end
  end
end
