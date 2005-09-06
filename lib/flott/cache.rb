module Flott
  class Cache
    # A Page object that encapsulates a compiled template.
    class Page
      # Creates a Page object for the template that can be found at
      # path _path_.
      def initialize(cache, path)
        @cache  = cache
        @path   = path
        compile
      end

      # Returns the compiled template or nil if the template
      # hasn't been compiled.
      attr_reader :template

      # If the file at _path_ has changed this method
      # returns true. It always returns true, if the attribute
      # _reload_time_ is set to a value < 0. If
      # _reload_time_ is set to a value >= 0, it will
      # return true only after _reload_time_ seconds (before that
      # time has passed nil is returned), even if the file has changed.
      def changed?
        return true if @cache.reload_time and @cache.reload_time < 0
        if @cache.reload_time and Time.now - @template.mtime < @cache.reload_time
          return
        end
        @template.mtime != @mtime
      end

      # Compile the file at _path_ with
      # a Flott::Parser instance and return it. This implies
      # that the _template_ attribute is set to the
      # return value for later reuse without compiling.
      def compile
        parser    = Parser.from_filename(@path)
        @template = parser.compile
        @mtime    = @template.mtime
      end
    end

    # Creates a Cache that compiles and caches the template files under
    # _rootdir_. If _reload_time_ in seconds is given,
    # the template files are only reloaded after _reload_time_
    # seconds even if changed. Negative _reload_time_ means, reload
    # the file always, even if unchanged. (This is good for development, think
    # of changed included templates.)
    def initialize(rootdir, reload_time = nil)
      @rootdir      = rootdir
      @reload_time  = reload_time
      @pages        = {}
    end

    # Reload time in seconds for the template files of this Cache.
    attr_accessor :reload_time

    # Returns all page names that can be cached by this Cache. These are
    # the template files under _rootdir_.
    def pages
      require 'find'
      page_names = []
      prefix = File.join(@rootdir, '')
      Find.find(@rootdir) do |path|
        pagename = path.sub(prefix, '')
        if !/^\./.match(pagename) && File.file?(path.untaint)
          page_names << pagename.untaint
        end
      end
      page_names
    end

    # Return the page that was compiled and/or cached with the name
    # _name_. If block is given the page is yielded to instead.
    def get(name)
      page = @pages[name]
      if page
        if page.changed?
          page.compile
        end
      else
        page = Page.new(self, File.join(@rootdir, name))
        page.compile
        put(name, page)
      end
      if block_given?
        yield page.template
        self
      else
        return page.template
      end
    rescue Errno::ENOENT, Errno::EISDIR
    end

    def evaluate(name, env = Environment.new)
      get(name) { |template| template.evaluate(env) } or return
      self
    end

    # Puts _page_ into the cache using the key _name_.
    def put(name, page)
      @pages[name] = page
    end
    private :put
  end
end
  # vim: set et sw=2 ts=2:
