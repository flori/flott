# XXX
# If two template files are saved in the current directory.
# One file "header":
#  <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
#     "http://www.w3.org/TR/html4/strict.dtd">
#  <html>
#   <head>
#    <title>Hello [=@name]!</title>
#    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
#   </head>
#   <body>
# And one file "template":
#  [<header]
#   <h1>Hello [=@name]!</h1>
#   [for i in 1..6
#     if i % 2 == 0]
#       <b>Hello [=@name]!</b>
#     [else]
#       <i>Hello [=@name]!</i>
#     [end
#   end]
#   </body>
#  </html>
# 
# The parser can be used like this
#  fp = Flott::Parser.from_filename('template')
#  env = Flott::Environment.new
#  env[:name] = "Florian"
#  fp.evaluate(env)
#
# The output is created by including "header" into "template" with the
# <tt>[<filename]</tt> syntax. <tt>[!@name]</tt> is a shortcut for
# <tt>[print @name]</tt> while <tt>[=@name]</tt> first calls
# Flott::Parser.escape on @name. It's also possible to just print or puts
# strings.
#
# Note the use of the assignment to the instance variable @name before
# executing the template. The state passed to Parser#evaluate as
# an environment and can be referenced in the template itself with
# <tt>[=@name]</tt>.
#
# After execution the output is:
#  <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
#     "http://www.w3.org/TR/html4/strict.dtd">
#  <html>
#   <head>
#    <title>Hello Florian!</title>
#    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
#   </head>
#   <body>
#  
#   <h1>Hello Florian!</h1>
#  
#       <i>Hello Florian!</i>
#  
#       <b>Hello Florian!</b>
#  
#       <i>Hello Florian!</i>
#  
#       <b>Hello Florian!</b>
#  
#       <i>Hello Florian!</i>
#  
#       <b>Hello Florian!</b>
#  
#   </body>
#  </html>
require 'strscan'

# This module includes the Flott::Parser class, that can be used to compile
# Flott template files to Flott::Template objects, which can then be evaluted
# in a Flott::Environment.
module Flott
  class << self
    # True switches debugging mode on, false off.
    attr_accessor :debug
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

  # This module contains methods to make delegation easier, if
  # a class/module was extended with it.
  module Delegate
    # A method to easily delegate methods to an object, stored in an
    # instance variable, or to an object return by a method call. It's
    # used like this:
    #   class A
    #     extend Delegate
    #     delegate :method_here1, :@obj
    #     delegate :method_here2, :@obj,        :method_there2
    #     delegate :method_here3, :method_call, :method_there3
    #   end
    def delegate(method_name, obj, other_method_name = method_name)
      raise ArgumentError, "obj wasn't defined" unless obj
      obj = obj.to_s
      if obj[0] == ?@
        class_eval <<-EOS
          def #{method_name}(*args, &block)
            instance_variable_get('#{obj}').__send__(
              '#{other_method_name}', *args, &block)
          end
        EOS
      else
        class_eval <<-EOS
          def #{method_name}(*args, &block)
            __send__('#{obj}').__send__(
              '#{other_method_name}', *args, &block)
          end
        EOS
      end
    end
  end

  # This module contains methods to interpret filenames of the templates.
  module FilenameMixin
    # Interpret filename for included templates. Beginning with '/' is the root
    # directory, that is the workdir of the first parser in the tree. All other
    # pathes are treated relative to this parsers workdir.
    def interpret_filename(filename)
      filename.untaint
      if filename[0] == ?/ 
        filename = File.join(rootdir, filename[1, filename.size])
      elsif workdir
        filename = File.join(workdir, filename)
      end
      filename
    end
    private :interpret_filename
  end

  # This module can be included into classes that should act as an environment
  # for Flott templates. An instance variable @output
  # (EnvironmentExtension#output) should hold an output IO object. If no
  # initialize method is defined in the including class,
  # EnvironmentExtension#initialize uses STDOUT as this IO object.
  #
  # If the class has its own initialize method, the environment can
  # be initialized with EnvironmentExtension#environment_initialize like
  # this:
  #  class Environment
  #    include EnvironmentExtension
  #    def initialize(*a)
  #      environment_initialize(*a)
  #    end
  #  end
  module EnvironmentExtension
    # Creates an Environment object, that outputs to _output_. The default
    # ouput object is STDOUT, but any object that responds to #<< will do.
    # _escape_ is a object that responds to #call (usually a Proc instance),
    # and given a string, returns an escaped version of the string as an
    # result. _escape_ defaults to Flott::Parser::HTML_ESCAPE.
    def initialize(output = STDOUT, escape = Flott::Parser::HTML_ESCAPE)
      @output = output
      @__escape__ = escape
    end

    # Calls EnvironmentExtension#initialize. This method should be calle
    # from classes that include EnvironmentExtension to initialize the
    # environment.
    def environment_initialize(output = STDOUT)
      EnvironmentExtension.instance_method(:initialize).bind(self).call(output)
    end

    # The output object for this Environment object.
    attr_accessor :output

    # The escape object for this Environment object.
    attr_accessor :escape

    # Returns the root directory of this environment, it should be
    # constant during the whole evaluation.
    def rootdir
      @__rootdir__
    end

    # Returns the current work directory of this environment. Ths
    # value changes during evaluation of a template.
    def workdir
      @__workdir__ or raise EvalError, "workdir was undefined"
    end

    # Updates the instance variables of this environment with values from
    # _hash_.
    def update(hash)
      hash.each { |name, value| self[name] = value }
    end

    # Returns the instance variable _name_.
    def [](name)
      name = name.to_s
      name = "@#{name}" unless name[0] == ?@
      instance_variable_get name
    end

    # Sets the instance variable _name_ to _value_.
    def []=(name, value)
      name = name.to_s
      name = "@#{name}" unless name[0] == ?@
      instance_variable_set name, value
    end


    # Creates a function (actually, a singleton method) _id_ from the block
    # _block_ on this object.
    def function(id, &block)
      sc = class << self; self; end
      sc.instance_eval { define_method(id, &block) }
    end

    alias fun function

    private
   
    include Flott::FilenameMixin

    # Dynamically Include the template _filename_ into the current template,
    # that is, at run-time.
    def include(filename)
      filename = interpret_filename(filename)
      source = File.read(filename)
      Flott::Parser.new(source, workdir).evaluate(self.dup)
    rescue # TODO logging??
      print "[dynamic include of '#{filename}' failed]"
    end
    
    # Kernel#p redirected to @output.
    def p(*objects)
      objects.each do |o|
        string = o.inspect 
        @output << string
        @output << "\n" unless string[-1] == ?\n
      end
      nil
    end

    # Kernel#pp redirected to @output.
    def pp(*objects)
      require 'pp'
      objects.each { |o| PP.pp(o, @output) }
      nil
    end

    # The usual IO#puts call without any escaping.
    def puts!(*objects)
      objects.each do |o|
        string = o.to_s
        @output << string
        @output << "\n" unless string[-1] == ?\n
      end
      nil
    end
    
    # Call to IO#puts to print _objects_ after escaping all their String
    # representations.
    def puts(*objects)
      objects.each do |o|
        string = @__escape__.call(o)
        @output << string
        @output << "\n" unless string[-1] == ?\n
      end
      nil
    end

    # The usual IO#printf call without any escaping.
    def printf!(format, *args)
      @output << sprintf(format, args)
      nil
    end

    # Print _objects_ after escaping all their String representations.
    def printf(format, *args)
      @output << @__escape__.call(sprintf(format, args))
      nil
    end

    # The usual IO#print call without any escaping.
    def print!(*objects)
      objects.each do |o|
        @output << @__escape__.call(o)
      end
      nil
    end

    # Call to IO#print to print _objects_ after escaping all their String
    # representations.
    def print(*objects)
      objects.each do |o|
        @output << o.to_s
      end
      nil
    end

    # The usual IO#write call without any escaping.
    def write!(object)
      string object.to_s
      @output << string
      string.size
    end

    # Call to IO#write after escaping the argument _object_.
    def write(object)
      string = @__escape__.call(object)
      @output << string
      string.size
    end
  end

  # This class can instantiate environment objects to evaluate Flott Templates
  # in.
  class Environment
    include EnvironmentExtension
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

    # Returns the newest _mtime_ of all the involved #pathes.
    def mtime
      @pathes.map { |path| File.stat(path).mtime }.max
    end

    # Evaluates this Template Object in the Environment (first argument).
    def call(*)
      super
    rescue SyntaxError => e
      raise CallError.wrap(e)
    end

    alias evaluate call
  end

  # The Flott::Parser class creates parser objects, that can be used to compile
  # Flott template documents or files to Flott::Template іnstances.
  class Parser
    # This class encapsulates the state, that is shared by all parsers
    # that were activated during the parse phase.
    class State
      extend Delegate

      # Creates a new Flott::Parser::State instance to hold the current
      # parser state.
      def initialize
        @opened       = 0
        @last_open    = nil
        @text         = []
        @compiled     = []
        @pathes       = []
        @directories  = []
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

      # A stack array, that contains the work directories of all active templates
      # (during parsing).
      attr_reader :directories

      # Transform text mode parts to compiled code parts.
      def text2compiled
        return if text.empty?
        compiled << %{@output<<'}
        compiled.concat(text)
        compiled << "'\n"
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
      delegate :top_workdir, :directories, :last

      # Pops the top directory from the _directories_ stack.
      def pop_workdir
        directories.empty? and raise CompileError, "state directories were empty"
        directories.pop
        compiled << "@__workdir__ = '#{top_workdir}'\n"
        self
      end
    end

    include Flott::FilenameMixin

    ESCOPEN   =   /\\\[/
    INCOPEN   =   /\[<\s*([^\]]+)\s*\]/
    PRIOPEN   =   /\[=\s*/
    RAWOPEN   =   /\[!\s*/
    COMOPEN   =   /\[#\s*/
    OPEN      =   /\[/
    CLOSE     =   /\]/
    ESCCLOSE  =   /\\\]/
    TEXT      =   /[^\\\]\[]+/
    ESC       =   /\\/

    # Creates a Parser object. _workdir_ is the directory, on which relative
    # template inclusions are based.
    def initialize(source, workdir = nil)
      if workdir
        @workdir = File.expand_path(workdir)
      else
        @workdir = File.expand_path(Dir.pwd)
      end
      @ruby = RubyMode.new(self)
      @text = TextMode.new(self)
      @current_mode = @text
      @scanner = StringScanner.new(source)
    end

    # Creates a Parser object from _filename_, the _workdir_ attribute is set
    # to the directory the file is located in.
    def self.from_filename(filename)
      filename  = File.expand_path(filename)
      workdir   = File.dirname(filename)
      source    = File.read(filename)
      obj = new(source, workdir)
      obj.instance_variable_set :@filename, filename
      obj
    end

    # The StringScanner instance of this Parser object.
    attr_reader :scanner

    # Returns the shared state between all parsers that are parsing
    # the current template and the included templates.
    def state
      @state ||= parent.state
    end

    # Returns nil if this is the root parser, or a reference to the parent
    # parser of this parser.
    attr_accessor :parent

    # Compute the rootdir of this parser (these parsers). Cache the
    # result and return it.
    def rootdir
      @rootdir ||= parent ? parent.rootdir : @workdir
    end

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
        "::Flott::Template.new { |env| env.instance_eval %q{\n",
        "@__rootdir__ = '#{rootdir}'\n",
      ]
      state.pathes << @filename if @filename
      compile_inner
      state.compiled << "\n}\n}"
      string = state.compiled_string
      template = eval(string, nil, '(flott)')
      template.pathes = state.pathes
      template
    rescue SyntaxError => e
      raise EvalError.wrap(e)
    end

    # Include the template _filename_ at the current place 
    def include_template(filename)
      filename = interpret_filename(filename)
      if File.readable?(filename)
        state.text2compiled
        state.pathes << filename
        source  = File.read(filename)
        workdir = File.dirname(filename)
        fork(source, workdir)
      else
        raise CompileError, "Cannot open #{filename} for inclusion!"
      end
    end

    # Fork another Parser to handle an included template.
    def fork(source, workdir)
      parser        = self.class.new(source, workdir)
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
      
      # The parsing mode uses this StringScanner instance for it's job,
      # its the StringScanner of the current _parser_.
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
        when scanner.scan(ESCOPEN)
          state.text << '['
        when scanner.scan(INCOPEN)
          state.last_open = :INCOPEN
          parser.include_template(scanner[1])
        when scanner.scan(PRIOPEN)
          state.last_open = :PRIOPEN
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << '@output<<@__escape__.call(begin '
        when scanner.scan(RAWOPEN)
          state.last_open = :RAWOPEN
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << '@output<<(begin '
        when scanner.scan(COMOPEN)
          state.last_open = :COMOPEN
          parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "\n=begin\n"
        when scanner.scan(OPEN)
          state.last_open = :OPEN
          parser.goto_ruby_mode
          state.text2compiled
        when scanner.scan(CLOSE)
          state.text << scanner[0]
        when scanner.scan(TEXT), scanner.scan(ESC)
          state.text << scanner[0].gsub(/'/, %{\\\\'}) if scanner[0]
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
        when scanner.match?(CLOSE) && state.opened == 0
          scanner.skip(CLOSE)
          parser.goto_text_mode
          case state.last_open
          when :PRIOPEN
            state.compiled << " end)\n"
          when :RAWOPEN
            state.compiled << " end.to_s)\n"
          when :COMOPEN
            state.compiled << "\n=end\n"
          else
            state.compiled << "\n"
          end
          state.last_open = nil
        when scanner.scan(ESCCLOSE)
          state.compiled << scanner[0]
        when scanner.scan(CLOSE) && state.opened != 0
          state.opened -= 1
          state.compiled << scanner[0]
        when scanner.scan(ESCOPEN)
          state.compiled << scanner[0]
        when scanner.scan(OPEN)
          state.opened += 1
          state.compiled << scanner[0]
        when scanner.scan(TEXT)
          state.compiled << scanner[0]
        else
          raise CompileError, "unknown tokens '#{scanner.peek(40)}'"
        end
      end
    end

    def debug_output
      if Flott.debug
        require 'pp'
        pp([ @current_mode.class, state.last_open, state.opened,
          state.compiled_string, state.directories, scanner.peek(20) ])
      end
    end
    private :debug_output

    def compile_inner(workdir_changed = true)  # :nodoc:
      scanner.reset
      workdir_changed and state.push_workdir(self)
      until scanner.eos?
        debug_output
        @current_mode.scan
      end
      debug_output
      state.text2compiled
      workdir_changed and state.pop_workdir
      debug_output
    end
    protected :compile_inner

    # First compiles the source template and evaluates it in the environment
    # env. If no environment is given, a newly created environment is used.
    def evaluate(env = Environment.new, &block)
      env.instance_eval(&block) if block
      compile.evaluate(env)
      self
    end

    # The already compiled ruby code is evaluated in the environment env.
    # If no environment is given, a newly created environment is used.
    def self.evaluate(compiled, env = Environment.new, &block)
      env.instance_eval(&block) if block
      compiled.evaluate(env)
      self
    end

    # Returns true if the source template is well formed. (That means at the
    # moment that brackets are balanced and all includes could be found.)
    # Otherwise false is returned. However, this doesn't mean that the
    # generated ruby code is bugfree or even valid.
    def wellformed?
      compile
    rescue
      false
    end

    # This Proc object escapes _string_, by substituting &<>"' with
    # their respective html entities, and returns the result.
    HTML_ESCAPE = lambda do |string|
      string.to_s.gsub(/[&<>"']/) do |c|
        case c
        when '&' then '&amp;'
        when '<' then '&lt;' 
        when '>' then '&gt;'
        when '"' then '&quot;'
        when "'" then '&apos;'
        else raise "unknown character '#{c}'"
        end
      end
    end
  end

  autoload :Cache, 'flott/cache'
end

if $0 == __FILE__
  parser = if filename = ARGV.shift
    Flott::Parser.from_filename(filename)
  else
    Flott::Parser.new(STDIN.read)
  end
  if parser.wellformed?
    STDERR.puts 'ok'
    exit 0
  else
    STDERR.puts 'not ok'
    exit 1
  end
end
  # vim: set et sw=2 ts=2: 
