module CookbookOmnifetch
  # A staging area in which the caller can stage files and publish them to a
  # local directory.
  #
  # When performing long operations such as installing or updating a cookbook
  # from the web, {StagingArea} allows you to minimize the risk that a process
  # running in parallel might retrieve an incomplete cookbook from the local
  # cache before it is completely installed. (See {publish!} for details.)
  #
  # {StagingArea} allocates temporary directories on the local file system.  It
  # is the caller's responsibility to use {discard!} when it is done to remove
  # those directories.  The {.stage} method handles directory cleanup for the
  # staging area it creates before returning.
  #
  # @example installing files using the {.stage} helper
  #   CookbookOmnifetch::StagingArea.stage(install_path) do |staging_path|
  #     # Copy files to staging_path
  #   end
  #
  # @example creating a staging area and publishing it manually
  #   stage = CookbookOmnifetch::StagingArea.new
  #   # Copy files to stage.path
  #   stage.publish!(install_path)
  #   stage.discard!
  class StagingArea
    # Creates a staging area, calls a block to populate it, then publishes it.
    #
    # {stage} creates a staging area and calls the provided block to populate it
    # with files. If the staging area does not contain any changes for
    # +target_path+ (see {#match?}), it cleans up the staging area without
    # modifying +target_path+.  Otherwise, it publishes its contents to
    # +target_path+ and deletes the staging area.  As a safety measure, {stage}
    # will not publish an empty staging area.
    #
    # @param [Pathname] target_path
    #   directory to which the staging area will publish its contents
    #
    # @yieldparam staging_path [Pathname]
    #   the directory in which the block should stage its files
    def self.stage(target_path)
      sa = new
      begin
        yield(sa.path)
        sa.publish!(target_path) unless sa.empty? || sa.match?(target_path)
      ensure
        sa.discard!
      end
    end

    # Returns true if the staging area is no longer available for use.
    #
    # The staging area is no longer available once {discard!} removes it from
    # the file system.
    #
    # @return [Boolean] whether the staging area is unavailable
    def unavailable?
      !!@unavailable
    end

    # Returns true if the staging area is empty.
    #
    # A staging area is considered empty when it has no files or directories in
    # its path or the staging directory does not exist.
    #
    # @raise [StagingAreaNotAvailable]
    #   when called after the staging area destroyed with {discard!}
    #
    # @return [Boolean] whether the staging area is empty
    def empty?
      !path.exist? || path.empty?
    end

    # Returns true if the staging area's contents match those of a given path.
    #
    # {#match?} compares the contents of the staging area with the contents of
    # the +compare_path+.  It considers the staging area to match if it contains
    # all of and nothing more than the files and directories present in
    # +compare_path+ and the content of each file is the same as that of its
    # corresponding file in +compare_path+.  {match?} does not compare file
    # metadata or the contents of special files.
    #
    # @param [String] compare_path
    #   the directory to which the staging area will compare its contents
    #
    # @raise [StagingAreaNotAvailable]
    #   when called after the staging area destroyed with {discard!}
    #
    # @return [Boolean] whether the staging area matches +compare_path+
    def match?(compare_path)
      raise StagingAreaNotAvailable if unavailable?

      target = Pathname(compare_path)
      return false unless target.exist?

      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: path)
      target_files = Dir.glob("**/*", File::FNM_DOTMATCH, base: target)
      return false unless files.sort == target_files.sort

      files.each do |subpath|
        return false if files_different?(path, target, subpath)
      end

      true
    end

    # Path to the staging folder on the file system.
    #
    # @raise [StagingAreaNotAvailable]
    #   when called after the staging area destroyed with {discard!}
    #
    # @return [Pathname] path to the staging folder
    def path
      raise StagingAreaNotAvailable if unavailable?

      return @path unless @path.nil?

      # Dir.mktmpdir returns a directory with restrictive permissions that it
      # doesn't support modifying, so create a subdirectory under it with
      # regular permissions for staging.
      @stage_tmp = Dir.mktmpdir
      @path = Pathname.new(File.join(@stage_tmp, "staging"))
      FileUtils.mkdir(@path)
      @path
    end

    # Removes the staging area and its contents from the file system.
    #
    # The staging area is no longer available once {discard!} removes it from
    # the file system.  Future attempts to use it will raise
    # {StagingAreaNotAvailable}.
    def discard!
      FileUtils.rm_rf(@stage_tmp) unless @stage_tmp.nil?
      @unavailable = true
    end

    # Replaces +install_path+ with the contents of the staging area.
    #
    # {publish!} removes the target and copies the new content into place using
    # two atomic file system operations.  This eliminates much of the risk
    # associated with updating the target in a multiprocess environment by
    # ensuring that another process does not see a partially removed or
    # populated directory at the +target_path+ while this operation is being
    # performed.
    #
    # Note that it is still possible for the {publish!} to interrupt another
    # process performing a long operation, such as creating a recursive copy of
    # the target.  In this situation, the other process may create a copy that
    # consists of a combination of content from the old target directory and the
    # newly staged files.  The other process may also raise an exception should
    # it try to access the target during a small window in the {publish!}
    # operation where the target directory does not exist, or tries to open a
    # file that is no longer part of the target tree after {publish!} completes.
    # The other process can detect this situation by verifying that the content
    # of its copy matches the content of +target_path+ after its copy is
    # complete.
    #
    # @param [String] install_path
    #   directory to which the staging area will publish its contents
    #
    # @raise [StagingAreaNotAvailable]
    #   when called after the staging area destroyed with {discard!}
    def publish!(install_path)
      target = Pathname(install_path)
      cache_dir = target.parent
      cache_dir.mkpath
      Dir.mktmpdir("_STAGING_TMP_", cache_dir) do |tmpdir|
        newtmp = File.join(tmpdir, "new_cookbook")
        oldtmp = File.join(tmpdir, "old_cookbook")
        FileUtils.cp_r(path, newtmp)

        # We could achieve an atomic replace using symbolic links, if they are
        # supported on all platforms.
        File.rename(target, oldtmp) if target.exist?
        File.rename(newtmp, target)
      end
    end

    private

    # compares two files
    def files_different?(base1, base2, subpath)
      file1 = File.join(base1, subpath)
      file2 = File.join(base2, subpath)
      return true unless File.ftype(file1) == File.ftype(file2)
      return true if File.file?(file1) && !FileUtils.cmp(file1, file2)

      false
    end
  end
end
