module Flott
  class PageCache
    # A Page object that encapsulates a compiled template.
    class Page
      # Creates a Page object for the template that can be found at
      # path <code>path</code>.
      def initialize(path, cache)
        @path   = path
        @cache  = cache
        @mtime  = File.stat(path).mtime
      end

      # Returns the compiled template or nil if the template
      # hasn't been compiled.
      attr_reader :template

      # If the file at <code>path</code> has changed this method
      # returns true. It always returns true, if the attribute
      # <code>reload_time</code> is set to a value < 0. If
      # <code>reload_time</code> is set to a value >= 0, it will
      # return true only after <code>reload_time</code> seconds (before that
      # time has passed nil is returned), even if the file has changed.
      def changed?
        return true if @cache.reload_time and @cache.reload_time < 0
        if @cache.reload_time and Time.now - @mtime < @cache.reload_time
          return
        end
        File.stat(@path).mtime != @mtime
      end

      # Compile the file at <code>path</code> with
      # a Flott::Parser instance and return it. This implies
      # that the <code>template</code> attribute is set to the
      # return value for later reuse without compiling.
      def compile(workdir = nil)
        parser = Parser.new(workdir)
        file = File.new(@path)
        source = file.read
        @mtime = file.stat.mtime
        @template = parser.compile(source)
      end

    end

    # Create a PageCache that compiles and caches the template files under
    # <code>pages_path</code>. If <code>reload_time</code> in seconds is given, the
    # template files are only reloaded after <code>reload_time</code> seconds
    # even if changed. Negative <code>reload_time</code> means, reload the
    # file always, even if unchanged. (This is good for development, think of changed
    # included templates.)
    def initialize(pages_path, reload_time = nil)
      @pages_path  = pages_path
      @workdir = File.dirname(@pages_path)
      @reload_time = reload_time
      @pages = {}
    end

    # Reload time in seconds for the template files of this PageCache.
    attr_reader :reload_time

    # Returns all page names that can be cached by this PageCache. These are
    # the template files under <code>pages_path</code>.
    def pages
      require 'find'
      page_names = []
      prefix = File.join(@pages_path, '')
      Find.find(@pages_path) do |path|
        pagename = path.sub(prefix, '')
        if !/^\./.match(pagename) && File.file?(path.untaint)
          page_names << pagename.untaint
        end
      end
      page_names
    end

    # Return the page that was compiled and/or cached with the name
    # <code>name</code>. If block is given the page is yielded to instead.
    def get(name)
      page = @pages[name]
      if page
        page.changed? and page.compile(@workdir)
      else
        page = Page.new(File.join(@pages_path, name), self)
        page.compile(@workdir)
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

    def evaluate(name, env = Object.new)
      get(name) { |template| Flott::Parser.evaluate(template, env) } or return
      self
    end

    # Puts <code>page</code> into the cache using the key <code>name</code>.
    def put(name, page)
      @pages[name] = page
    end
    private :put
  end
end
  # vim: set et sw=2 ts=2:
