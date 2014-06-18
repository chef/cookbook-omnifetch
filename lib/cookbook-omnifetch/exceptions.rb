module CookbookOmnifetch


  class AbstractFunction < StandardError; end

  class GitError < StandardError; end

  class GitNotInstalled < GitError
    def initialize
      super 'You need to install Git before you can download ' \
        'cookbooks from git repositories. For more information, please ' \
        'see the Git docs: http://git-scm.org.'
    end
  end

  class GitCommandError < GitError
    def initialize(command, path, stderr = nil)
      out =  "Git error: command `git #{command}` failed. If this error "
      out << "persists, try removing the cache directory at '#{path}'."

      if stderr
        out << "Output from the command:\n\n"
        out << stderr
      end

      super(out)
    end
  end

end
