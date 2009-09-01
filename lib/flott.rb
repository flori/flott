require 'strscan'

# This module includes the Flott::Parser class, that can be used to compile
# Flott template files to Flott::Template objects, which can then be evaluted
# in a Flott::Environment.
module Flott
  require 'flott/version'
  autoload :Cache, 'flott/cache'

  module ::Kernel
    private

    # Evaluate +object+ with Flott and return the output. +object+ can either be
    # like a string (responding to :to_str), an IO instance (responding to
    # :to_io), or respond to :evaluate like Flott::Template. The environment
    # and (root) template used is attached to the output ring as the mehthods
    # environment and template respectively.
    def Flott(object, env = Environment.new, &block)
      if object.respond_to?(:evaluate)
        Flott.evaluate(object, env, &block)
        env.output
      elsif object.respond_to?(:to_str)
        Flott.string_from_source(object.to_str, env, &block)
      elsif object.respond_to?(:to_io)
        Flott.string_from_source(object.to_io.read, env, &block)
      else
        raise TypeError,
          "require an evaluable object, a String, or an IO object"
      end
    end
  end

  class << self
    # True switches debugging mode on, false off. Defaults to false.
    attr_accessor :debug

    # Return the compiled template of +source+ while passing the remaining
    # arguments through to Flott::Parser.new.
    def compile(source, workdir = nil, rootdir = nil, filename = nil)
      parser = Flott::Parser.new(source, workdir, rootdir, filename)
      parser.compile
    end

    # The already compiled ruby code is evaluated in the environment env. If no
    # environment is given, a newly created environment is used. This method
    # doesn't return the result directly, only via the effects on the environment.
    def evaluate(compiled, env = Environment.new, &block)
      if !(EnvironmentMixin === env) and env.respond_to? :to_hash
        env = Environment.new.update(env.to_hash)
      end
      env.instance_eval(&block) if block
      compiled.evaluate(env)
      self
    end

    # Evaluate the template source _source_ in environment _env_ and with the
    # block _block_. If no environment is given, a newly created environment is
    # used. This method doesn't return the result directly, only via the
    # effects on the environment.
    def evaluate_source(source, env = Environment.new, &block)
      if !(EnvironmentMixin === env) and env.respond_to? :to_hash
        env = Environment.new.update(env.to_hash)
      end
      env.instance_eval(&block) if block
      parser = Parser.new(source)
      parser.evaluate(env)
      self
    end

    # Evaluate the template file _filename_ in environment _env_ and with the
    # block _block_. If no environment is given, a newly created environment is
    # used. This method doesn't return the result directly, only via the
    # effects on the environment.
    def evaluate_file(filename, env = Environment.new, &block)
      if !(EnvironmentMixin === env) and env.respond_to? :to_hash
        env = Environment.new.update(env.to_hash)
      end
      env.instance_eval(&block) if block
      parser = Parser.from_filename(filename)
      parser.evaluate(env)
      self
    end

    # Create an output string from template source _source_, evaluated in the
    # Environment _env_. If _block_ is given it is evaluated in the _env_
    # context as well.
    def string_from_source(source, env = Environment.new, &block)
      if !(EnvironmentMixin === env) and env.respond_to? :to_hash
        env = Environment.new.update(env.to_hash)
      end
      output = ''
      env.output = output
      env.instance_eval(&block) if block
      parser = Parser.new(source)
      parser.evaluate(env)
      env.output
    end

    # Create an output string from the template file _filename_, evaluated in the
    # Environment _env_. If _block_ is given it is evaluated in the _env_ context
    # as well. This will set the rootdir and workdir attributes, in order to
    # dynamic include other templates into this one.
    def string_from_file(filename, env = Environment.new, &block)
      if !(EnvironmentMixin === env) and env.respond_to? :to_hash
        env = Environment.new.update(env.to_hash)
      end
      output = ''
      env.output = output
      env.instance_eval(&block) if block
      parser = Parser.from_filename(filename)
      parser.evaluate(env)
      env.output
    end
  end
  Flott.debug = false

  # The base exception of all Flott Exceptions, Errors.
  class FlottException < StandardError
    # Wrap _exception_ into a FlottException, including the given backtrace.
    def self.wrap(exception)
      wrapper = new(exception.message)
      wrapper.set_backtrace exception.backtrace
      wrapper
    end
  end

  # The base Exception for Parser errors.
  class ParserError < FlottException; end

  # This exception is raised if errors happen in the compilation phase of a
  # template.
  class CompileError < ParserError; end

  # This exception is raised if a syntax error occurs during the
  # evaluation of the compiled Ruby code.
  class EvalError < ParserError; end

  # This exception is raised if a syntax error occurs while
  # calling the evaluated Proc object.
  class CallError < ParserError; end

  class SecurityViolation < ParserError; end

  # This module contains methods to interpret filenames of the templates.
  module FilenameMixin
    # Interpret filename for included templates. Beginning with '/' is the root
    # directory, that is the workdir of the first parser in the tree. All other
    # pathes are treated relative to this parsers workdir.
    def interpret_filename(filename)
      filename.untaint
      if filename[0] == ?/ 
        filename = File.join(rootdir, filename[1..-1])
      elsif workdir
        filename = File.join(workdir, filename)
      end
      File.expand_path(filename)
    end
    private :interpret_filename

    def interpret_filename_as_page(filename)
      filename.untaint
      if filename[0] == ?/ 
        filename = filename[1..-1]
      elsif workdir
        filename = File.expand_path(File.join(workdir, filename))
        filename[rootdir] = ''
      end
      filename
    end
    private :interpret_filename

    def check_secure_path(path)
      if File::ALT_SEPARATOR
        if path.split(File::ALT_SEPARATOR).any? { |p| p == '..' }
          raise SecurityViolation, "insecure path '#{path}' because of '..'"
        end
      else
        if path[0] == ?~
          raise SecurityViolation,
            "insecure path '#{path}' because of starting '~'"
        end
        if path.split(File::SEPARATOR).any? { |p| p == '..' }
          raise SecurityViolation, "insecure path '#{path}' because of '..'"
        end
      end
    end
    private :check_secure_path

    
    def sub_path?(sp, path)
      sp[/\A#{path}/] == path
    end
    private :sub_path?
  end

  # This module can be included into classes that should act as an environment
  # for Flott templates. An instance variable @__output__
  # (EnvironmentMixin#output) should hold an output object, that responds
  # to the #<< method, usually an IO object. If no initialize method is defined
  # in the including class, EnvironmentMixin#initialize uses STDOUT as this
  # _output_ object.
  #
  # If the class has its own initialize method, the environment can be
  # initialized with super(output, escape)
  # class Environment
  #    include EnvironmentMixin
  #    def initialize(output, escape)
  #      super(output, escape)
  #    end
  #  end
  module EnvironmentMixin
    # Creates an Environment object, that outputs to _output_. The default
    # ouput object is STDOUT, but any object that responds to #<< will do.
    # _escape_ is a object that responds to #call (usually a Proc instance),
    # and given a string, returns an escaped version of the string as an
    # result. _escape_ defaults to Flott::Parser::HTML_ESCAPE.
    def initialize(output = STDOUT, escape = Flott::Parser::HTML_ESCAPE)
      @__output__ = output
      @__escape__ = escape
    end

    # The output object for this Environment object. It should respond to the
    # #<< method of appending strings.
    def output
      @__output__
    end
    
    # Sets the output object for this Environment object, to _output_. It
    # should respond to the #<< method of appending strings.
    def output=(output)
      @__output__ = output
    end

    # The escape object for this Environment object.
    attr_accessor :escape

    # If the currently evaluated Template originated from a Flott::Cache this
    # method returns it, otherwise nil is returned.
    attr_accessor :page_cache

    # The template that was evaluated in this environment last.
    attr_accessor :template

    # Returns the root directory of this environment, it should be
    # constant during the whole evaluation.
    def rootdir
      @__rootdir__
    end

    # Returns the current work directory of this environment. This
    # value changes during evaluation of a template.
    def workdir
      @__workdir__ or raise EvalError, "workdir was undefined"
    end

    # Updates the instance variables of this environment with values from
    # _hash_.
    def update(hash)
      hash.each { |name, value| self[name] = value }
      self
    end

    # Returns the instance variable _name_. The leading '@' can be omitted in
    # _name_.
    def [](name)
      name = name.to_s
      name = "@#{name}" unless name[0] == ?@
      instance_variable_get name
    end

    # Sets the instance variable _name_ to _value_. The leading '@' can be
    # omitted in _name_.
    def []=(name, value)
      name = name.to_s
      name = "@#{name}" unless name[0] == ?@
      instance_variable_set name, value
    end

    # Creates a function (actually, a singleton method) _id_ from the block
    # _block_ on this object, that can be called later in the template:
    #  [function :fac do |n|
    #    if n < 2
    #      1
    #    else
    #      n * fac(n - 1)
    #    end
    #  end]
    #  fac(10) = [=fac(10)]
    def function(id, opts = {}, &block)
      sc = class << self; self; end
      if opts[:memoize]
        cache = {}
        sc.instance_eval do
          define_method(id) do |*args|
            if cache.key?(args)
              cache[args]
            else
              cache[args] = block[args]
            end
          end
        end
      else
        sc.instance_eval { define_method(id, &block) }
      end
      nil
    end

    alias fun function

    # Memoize method with id _id_, if called.
    def memoize(id)
      cache = {}
      old_method = method(id)
      sc = class << self; self; end
      sc.send(:define_method, id) do |*args|
        if cache.key?(args)
          cache[args]
        else
          cache[args] = old_method.call(*args)
        end
      end
    end

    private
   
    include Flott::FilenameMixin

    # Dynamically Include the template _filename_ into the current template,
    # that is, at run-time.
    def include(filename)
      check_secure_path(filename)
      if page_cache
        page_cache.get(interpret_filename_as_page(filename)).evaluate(self.dup)
      else
        filename = interpret_filename(filename)
        source = File.read(filename)
        Flott::Parser.new(source, workdir).evaluate(self.dup)
      end
    rescue # TODO logging??
      print "[dynamic include of '#{filename}' failed]"
    end
    
    # Like Kernel#p but with escaping.
    def p(*objects)
      for o in objects
        string = @__escape__.call(o.inspect)
        @__output__ << string
        @__output__ << "\n" unless string[-1] == ?\n
      end
      nil
    end

    # Like Kernel#p without any escaping.
    def p!(*objects)
      for o in objects
        string = o.inspect
        @__output__ << string
        @__output__ << "\n" unless string[-1] == ?\n
      end
      nil
    end

    # Like Kernel#pp but with escaping.
    def pp(*objects)
      require 'pp'
      for o in objects
        string = ''
        PP.pp(o, string)
        @__output__ << @__escape__.call(string)
        @__output__ << $/ unless string =~ /\r?#$/\Z/
      end
      nil
    end

    # Like Kernel#pp without any escaping.
    def pp!(*objects)
      require 'pp'
      for o in objects
        string = ''
        PP.pp(o, string)
        @__output__ << string
        @__output__ << $/ unless string =~ /\r?#$/\Z/
      end
      nil
    end

    # The usual IO#puts call without any escaping.
    def puts!(*objects)
      for o in objects.flatten
        string = o.to_s
        @__output__ << string
        @__output__ << $/ unless string =~ /\r?#$/\Z/
      end
      nil
    end
    
    # Like a call to IO#puts to print _objects_ after escaping all their #to_s
    # call results.
    def puts(*objects)
      for o in objects.flatten
        string = @__escape__.call(o)
        @__output__ << string
        @__output__ << $/ unless string =~ /\r?#$/\Z/
      end
      nil
    end

    def putc!(object)
      if object.is_a? Numeric
        @__output__ << object.chr
      else
        @__output__ << object.to_s[0, 1]
      end
    end

    def putc(object)
      if object.is_a? Numeric
        @__output__ << @__escape__.call(object.chr)
      else
        @__output__ << @__escape__.call(object[0, 1])
      end
    end

    # Like the usual IO#printf call without any escaping.
    def printf!(format, *args)
      @__output__ << sprintf(format, *args)
      nil
    end

    # Like a call to IO#printf, but with escaping the string before printing.
    def printf(format, *args)
      @__output__ << @__escape__.call(sprintf(format, *args))
      nil
    end

    # Like the usual IO#print call without any escaping.
    def print!(*objects)
      for o in objects
        @__output__ << o.to_s
      end
      nil
    end

    # Call to IO#print to print _objects_ after escaping all their #to_s
    # call results.
    def print(*objects)
      for o in objects
        @__output__ << @__escape__.call(o)
      end
      nil
    end

    # Like the usual IO#write call without any escaping.
    def write!(object)
      string = object.to_s
      @__output__ << string
      string.size
    end

    # Like a call to IO#write after escaping the argument _object_'s #to_s call
    # result.
    def write(object)
      string = @__escape__.call(object)
      @__output__ << string
      string.size
    end
  end

  # This class can instantiate environment objects to evaluate Flott Templates
  # in.
  class Environment
    include EnvironmentMixin
  end

  # Class for compiled Template objects, that can later be evaluated in a
  # Flott::Environment.
  class Template < Proc
    # Sets up a Template instance.
    def initialize
      super
      @pathes = []
    end

    # The pathes of the template and all included sub-templates.
    attr_accessor :pathes

    # Returns the Flott::Cache this Template originated from or nil, if no
    # cache was used.
    attr_accessor :page_cache

    # The environment this template was evaluated in during the last evaluate
    # call. Returns nil if it wasn't evaluated yet.
    attr_accessor :environment

    # Returns the newest _mtime_ of all the involved #pathes.
    def mtime
      @pathes.map { |path| File.stat(path).mtime }.max
    end

    # Evaluates this Template Object in the Environment _environment_ (first
    # argument).
    def call(environment = Flott::Environment.new, *)
      @environment = environment
      @environment.template = self
      @environment.page_cache = page_cache
      result = super
      attach_environment_to_output
      result
    rescue SyntaxError => e
      raise CallError.wrap(e)
    end

    alias evaluate call

    private

    def attach_environment_to_output
      o = @environment.output
      unless o.respond_to?(:environment=)
        class << o; self ; end.class_eval do
          attr_accessor :environment

          def template
            environment.template
          end
        end
      end
      o.environment = @environment
    end
  end

  # The Flott::Parser class creates parser objects, that can be used to compile
  # Flott template documents or files to Flott::Template instances.
  class Parser
    # This class encapsulates the state, that is shared by all parsers that
    # were activated during the parse phase.
    class State
      # Creates a new Flott::Parser::State instance to hold the current parser
      # state.
      def initialize
        @opened       = 0
        @last_open    = nil
        @text         = []
        @compiled     = []
        @pathes       = []
        @directories  = []
        @skip_cr      = false
      end

      # The number of current open (unescaped) brackets.
      attr_accessor :opened

      # The type of the last opened bracket.
      attr_accessor :last_open

      # An array of all scanned text fragments.
      attr_reader :text

      # An array of the already compiled Ruby code fragments.
      attr_reader :compiled

      # An array of involved template file pathes, that is, also the statically
      # included template file pathes.
      attr_reader :pathes

      # A stack array, that contains the work directories of all active
      # templates (during parsing).
      attr_reader :directories

      attr_accessor :skip_cr

      # Transform text mode parts to compiled code parts.
      def text2compiled(dont_sub = true)
        return if text.empty?
        text.last.sub!(/[\t ]+$/, '') unless dont_sub
        compiled << '@__output__<<%q['
        compiled.concat(text)
        compiled << "]\n"
        text.clear
      end

      # Return the whole compiled code as a string.
      def compiled_string
        compiled.join.untaint
      end

      # Pushs the workdir of _parser_ onto the _directories_ stack.
      def push_workdir(parser)
        workdir = parser.workdir
        compiled << "@__workdir__ = '#{workdir}'\n"
        directories << workdir
        self
      end

      # Returns the top directory from the _directories_ stack.
      def top_workdir
        directories.last
      end

      # Pops the top directory from the _directories_ stack.
      def pop_workdir
        directories.empty? and raise CompileError, "state directories were empty"
        directories.pop
        compiled << "@__workdir__ = '#{top_workdir}'\n"
        self
      end
    end

    include Flott::FilenameMixin

    # Regexp matching an escaped open square bracket like '\['.
    ESCOPEN   =   /\\\[/
    
    # [^filename]
    INCOPEN   =   /\[\^\s*([^\]]+?)\s*(-)?\]/
    # TODO allow ] in filenames?

    # [="foo<bar"] "foo&lt;bar"
    PRIOPEN   =   /\[=\s*/

    # [!"foo<bar"] "foo<bar"
    RAWOPEN   =   /\[!\s*/

    # [#comment]
    COMOPEN   =   /\[#\s*/

    # Open succeded by minus deletes previous whitespaces until start of line.
    MINPRIOPEN   =   /\[-=/

    # Open succeded by minus deletes previous whitespaces until start of line.
    MINRAWOPEN   =   /\[-!/

    # Open succeded by minus deletes previous whitespaces until start of line.
    MINCOMOPEN   =   /\[-#/

    # Open succeded by minus deletes previous whitespaces until start of line.
    MINOPEN      =   /\[-/

    # Regexp matching an open square bracket like '['.
    OPEN      =   /\[/

    # Close preceded by minus deletes next CRLF.
    MINCLOSE     =   /-\]/

    # Regexp matching an open square bracket like ']'.
    CLOSE     =   /\]/

    # Regexp matching an escaped closed square bracket like '\]'.
    ESCCLOSE  =   /\\\]/

    # Regexp matching general text, that doesn't need special handling.
    TEXT      =   /([^-\\\]\[\{\}]+|-(?!\]))/

    # Regexp matching the escape character '\'.
    ESC       =   /\\/

    # Regexp matching the escape character at least once.
    ESC_CLOSURE       =   /\\(\\*)/

    # Regexp matching curly brackets '{' or '}'.
    CURLY     =   /[{}]/

    # Regexp matching open curly bracket like '{'.
    CURLYOPEN =   /\{/

    # Regexp matching open curly bracket like '}'.
    CURLYCLOSE=   /\}/

    # Creates a Parser object. _workdir_ is the directory, on which relative
    # template inclusions are based. _rootdir_ is the directory. On which
    # absolute template inclusions (starting with '/') are based. _filename_ is
    # the filename of this template (if any), which is important to track
    # changes in the template file to trigger a reloading.
    def initialize(source, workdir = nil, rootdir = nil, filename = nil)
      if workdir
        check_secure_path(workdir)
        @workdir = File.expand_path(workdir)
      else
        @workdir = Dir.pwd
      end
      if rootdir
        check_secure_path(rootdir)
        @rootdir = File.expand_path(rootdir)
      else
        @rootdir = @workdir
      end
      sub_path?(@workdir, @rootdir) or
        raise SecurityViolation, "#{@workdir} isn't a sub path of '#{@rootdir}'"
      if filename
        check_secure_path(filename)
        @filename  = File.expand_path(filename)
        sub_path?(@filename, @workdir) or
          raise SecurityViolation, "#{@filename} isn't a sub path of '#{@workdir}"
      end
      @ruby = RubyMode.new(self)
      @text = TextMode.new(self)
      @current_mode = @text
      @scanner = StringScanner.new(source)
    end

    # Creates a Parser object from _filename_, the _workdir_ and _rootdir
    # attributes are set to the directory the file is located in.
    def self.from_filename(filename)
      filename  = File.expand_path(filename)
      workdir   = File.dirname(filename)
      source    = File.read(filename)
      new(source, workdir, workdir, filename)
    end

    # The StringScanner instance of this Parser object.
    attr_reader :scanner

    # Returns the shared state between all parsers that are parsing the current
    # template and the included templates.
    def state
      @state ||= parent.state
    end

    # Returns nil if this is the root parser, or a reference to the parent
    # parser of this parser.
    attr_accessor :parent

    # Compute the rootdir of this parser (these parsers). Cache the result and
    # return it.
    attr_reader :rootdir

    # Returns the current work directory of this parser.
    attr_accessor :workdir

    # Change parsing mode to TextMode.
    def goto_text_mode
      @current_mode = @text
    end

    # Change parsing mode to RubyMode.
    def goto_ruby_mode
      @current_mode = @ruby
    end

    # Compiles the template source and returns a Proc object to be executed
    # later. This method raises a ParserError exception if source is not
    # _Parser#wellformed?_.
    def compile
      @state = State.new
      state.compiled << [
        "::Flott::Template.new \{ |__env__| __env__.instance_eval %q{\n",
        "@__rootdir__ = '#{rootdir}'\n",
      ]
      state.pathes << @filename if defined?(@filename)
      compile_inner
      state.compiled << "\n}\n}"
      string = state.compiled_string
      template = eval(string, nil, '(flott)')
      template.pathes = state.pathes
      template
    rescue SyntaxError => e
      raise EvalError.wrap(e)
    end

    # Include the template file with _filename_ at the current place.
    def include_template(filename)
      filename = interpret_filename(filename)
      if File.readable?(filename)
        state.text2compiled
        state.pathes << filename
        source  = File.read(filename)
        workdir = File.dirname(filename)
        fork(source, workdir, rootdir, filename)
      else
        raise CompileError, "Cannot open #{filename} for inclusion!"
      end
    end

    # Fork another Parser to handle an included template.
    def fork(source, workdir, rootdir, filename)
      parser        = self.class.new(source, workdir, rootdir, filename)
      parser.parent = self
      parser.compile_inner(@workdir != workdir)
    end
  
    # The base parsing mode. 
    class Mode
      # Creates a parsing mode for _parser_.
      def initialize(parser)
        @parser = parser
      end

      # The parser this mode belongs to.
      attr_reader :parser
      
      # The parsing mode uses this StringScanner instance for it's job, its the
      # StringScanner of the current _parser_.
      def scanner
        @parser.scanner
      end

      # A shortcut to reach the shared state of all the parsers involved in
      # parsing the current template.
      def state
        @parser.state
      end
    end

    # This Mode class handles the Parser's TextMode state.
    class TextMode < Mode
      # Scan the template in TextMode.
      def scan
        case
        when state.skip_cr && scanner.skip(/[\t ]*\r?\n/)
          state.skip_cr = false
        when scanner.scan(ESCOPEN)
          state.text << '\\['
        when scanner.scan(CURLYOPEN)
          state.text << '\\{'
        when scanner.scan(INCOPEN)
          state.last_open = :INCOPEN
          parser.include_template(scanner[1])
          state.skip_cr = scanner[2]
        when scanner.scan(PRIOPEN)
          state.last_open = :PRIOPEN
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "@__output__<<@__escape__.call((\n"
        when scanner.scan(RAWOPEN)
          state.last_open = :RAWOPEN
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "@__output__<<((\n"
        when scanner.scan(COMOPEN)
          state.last_open = :COMOPEN
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "\n=begin\n"
        when scanner.scan(MINPRIOPEN)
          state.last_open = :PRIOPEN
          if t = state.text.last
            t.sub!(/[\t ]*\Z/, '')
          end
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "@__output__<<@__escape__.call((\n"
        when scanner.scan(MINRAWOPEN)
          state.last_open = :RAWOPEN
          if t = state.text.last
            t.sub!(/[\t ]*\Z/, '')
          end
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "@__output__<<((\n"
        when scanner.scan(MINCOMOPEN)
          state.last_open = :COMOPEN
          if t = state.text.last
            t.sub!(/[\t ]*\Z/, '')
          end
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "\n=begin\n"
        when scanner.scan(MINOPEN)
          state.last_open = :OPEN
          if t = state.text.last
            t.sub!(/[\t ]*\Z/, '')
          end
          parser.goto_ruby_mode
          state.text2compiled(false)
        when scanner.scan(OPEN)
          state.last_open = :OPEN
          parser.goto_ruby_mode
          state.text2compiled
        when scanner.scan(CLOSE)
          state.text << '\\' << scanner[0]
        when scanner.scan(TEXT)
          state.text << scanner[0]
        when scanner.scan(CURLYCLOSE)
          state.text << '\\' << scanner[0]
        when scanner.scan(ESC)
          state.text << '\\\\' << scanner[0]
        else
          raise CompileError, "unknown tokens '#{scanner.peek(40)}'"
        end
      end
    end

    # This Mode class handles the Parser's RubyMode state.
    class RubyMode < Mode
      # Scan the template in RubyMode.
      def scan
        case
        when state.opened == 0 && scanner.scan(MINCLOSE)
          state.skip_cr = true
          case state.last_open
          when :PRIOPEN
            state.compiled << "\n))\n"
          when :RAWOPEN
            state.compiled << "\n).to_s)\n"
          when :COMOPEN
            state.compiled << "\n=end\n"
          else
            state.compiled << "\n"
          end
          parser.goto_text_mode
          state.last_open = nil
        when state.opened == 0 && scanner.scan(CLOSE) 
          parser.goto_text_mode
          case state.last_open
          when :PRIOPEN
            state.compiled << "\n))\n"
          when :RAWOPEN
            state.compiled << "\n).to_s)\n"
          when :COMOPEN
            state.compiled << "\n=end\n"
          else
            state.compiled << "\n"
          end
          state.last_open = nil
        when scanner.scan(ESCCLOSE)
          state.compiled << scanner[0]
        when scanner.scan(CLOSE) && state.opened != 0,
            scanner.scan(MINCLOSE) && state.opened != 0
          state.opened -= 1
          state.compiled << scanner[0]
        when scanner.scan(ESCOPEN)
          state.compiled << scanner[0]
        when scanner.scan(OPEN)
          state.opened += 1
          state.compiled << scanner[0]
        when scanner.scan(TEXT)
          state.compiled << scanner[0]
        when scanner.scan(CURLY)
          state.compiled << '\\' << scanner[0]
        when scanner.scan(ESC_CLOSURE)
          s = scanner[0]
          ssize = s.size
          if ssize % 2 == 0
            state.compiled << s * 2
          else
            state.compiled << s[0, ssize - 1] * 2
            state.compiled << eval(%'"\\#{scanner.scan(/./)}"')
          end
        else
          raise CompileError, "unknown tokens '#{scanner.peek(40)}'"
        end
      end
    end

    def debug_output
      warn "%-20s:%s\n" % [ :mode,        @current_mode.class ]
      warn "%-20s:%s\n" % [ :last_open,   state.last_open ]
      warn "%-20s:%s\n" % [ :opened,      state.opened ]
      warn "%-20s:%s\n" % [ :directories, state.directories * ',' ]
      warn "%-20s:%s\n" % [ :peek,        scanner.peek(60) ]
      warn "%-20s:%s\n" % [ :compiled,    state.compiled_string ]
    end
    private :debug_output

    def compile_inner(workdir_changed = true)  # :nodoc:
      scanner.reset
      workdir_changed and state.push_workdir(self)
      until scanner.eos?
        Flott.debug && debug_output
        @current_mode.scan
      end
      Flott.debug && debug_output
      state.text2compiled
      workdir_changed and state.pop_workdir
      Flott.debug && debug_output
    end
    protected :compile_inner

    # First compiles the source template and evaluates it in the environment
    # env. If no environment is given, a newly created environment is used.
    def evaluate(env = Environment.new, &block)
      env.instance_eval(&block) if block
      compile.evaluate(env)
      self
    end

    # :stopdoc:
    ESCAPE_MAP = Hash.new { |h, c| raise "unknown character '#{c}'" }
    ESCAPE_MAP.update({
      ?& => '&amp;',
      ?< => '&lt;',
      ?> => '&gt;',
      ?" => '&quot;',
      ?' => '&apos;'
    })

    # This Proc object escapes _string_, by substituting &<>"' with their
    # respective html entities, and returns the result.
    HTML_ESCAPE = lambda do |string|
      if string.respond_to?(:to_str)
        string.to_str.gsub(/[&<>"']/) { |c| ESCAPE_MAP[c[0]] }
      else
        string = string.to_s
        string.gsub!(/[&<>"']/) { |c| ESCAPE_MAP[c[0]] }
        string
      end
    end
    # :startdoc:
  end
end

if $0 == __FILE__
  Flott.debug = $DEBUG
  parser = if filename = ARGV.shift
    Flott::Parser.from_filename(filename)
  else
    Flott::Parser.new(STDIN.read)
  end
  parser.evaluate
end
