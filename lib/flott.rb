require 'strscan'

# This module includes the Flott::Parser class, that can be used to 
# compile Flott-Templates to Flott::Template objects, which can then be
# evaluted in an Flott::Environment.
# 
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
module Flott
  class << self
    # True switches debugging mode on, false off.
    attr_accessor :debug
  end

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

  module Delegate
    # A method to easily delegate methods to an object, stored in an
    # instance variable, or to an object return by a reader attribute. It's
    # used like this:
    #   class A
    #     delegate :method_here1, :@obj
    #     delegate :method_here2, :@obj, :method_there2
    #     delegate :method_here3, :reader, :method_there3
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
    extend Delegate

    # Creates an Environment object, that outputs to _output_. The default
    # ouput stream is STDOUT.
    def initialize(output = STDOUT)
      @output = output
    end

    # Calls EnvironmentExtension#initialize. This method should be calle
    # from classes that include EnvironmentExtension to initialize the
    # environment.
    def environment_initialize(output = STDOUT)
      EnvironmentExtension.instance_method(:initialize).bind(self).call(output)
    end

    # The output object for the Environment objects.
    attr_writer :output

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
    
    # Include the template _filename_ into the current template at run-time.
    def include(filename)
      Flott::Parser.new(File.read(filename)).evaluate(self)
    end
    
    # Kernel#p redirected to @output.
    def p(*objects)
      objects.each { |o| @output.puts(o.inspect) }
      nil
    end

    # Kernel#pp redirected to @output.
    def pp(objects, out_ignore=nil, width = 79)
      require 'pp'
      objects.each { |obj| PP.pp(obj, @output) }
      nil
    end

    # The usual IO#puts call without any escaping.
    delegate :puts!,    :@output, :puts

    # Call to IO#puts to print _objects_ after escaping all their String
    # representations.
    def puts(*objects)
      @output.puts *objects.map { |o| Flott::Parser.escape(o) }
    end

    # The usual IO#printf call without any escaping.
    delegate :printf!,  :@output, :printf

    # Print _objects_ after escaping all their String representations.
    def printf(format, *args)
      @output.print Flott::Parser.escape(sprintf(format, args))
    end

    # The usual IO#print call without any escaping.
    delegate :print!,   :@output, :print

    # Call to IO#print to print _objects_ after escaping all their String
    # representations.
    def print(*objects)
      @output.print *objects.map { |o| Flott::Parser.escape(o) }
    end

    # The usual IO#putc call without any escaping.
    delegate :putc!,    :@output, :putc

    # Call to IO#putc after escaping the argument _object_.
    def putc(object)
      object = '' << object if object.is_a? Numeric
      @output.putc Flott::Parser.escape(object)
    end

    # The usual IO#write call without any escaping.
    delegate :write!,   :@output, :write

    # Call to IO#write after escaping the argument _string_.
    def write(string)
      @output.write Flott::Parser.escape(string)
    end
  end

  # This class can instantiate environment objects to evaluate Flott Templates
  # in.
  class Environment
    include EnvironmentExtension
  end

  class ParserState < Struct.new(:opened, :last_open, :text,
      :compiled, :pathes)
    # Transform text mode parts to compiled code parts.
    def text2compiled
      return if text.empty?
      compiled << %{print! '}
      compiled.concat(text)
      compiled << %{';}
      text.clear
    end

    # Return the whole compiled code as a string.
    def compiled_string
      compiled.join.untaint
    end
  end

  # Class for compiled Template objects, that can be evaluated later
  # in an Environment.
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

  # 
  class Parser
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

    # Creates a Parser object. _workdir_ is the directory, on which
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

    # Creates a Parser object from _filename_
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
      @state = ParserState.new(0, nil, [],
        [ "Template.new { |env| env.instance_eval %q{\n" ],
        @filename ? [ @filename ] : [])
      compile_inner
      state.compiled << "\n}\n}"
      string = state.compiled_string
      create_template(string)
    end

    def create_template(string)
      template = eval(string, nil, '(flott)')
      template.pathes = state.pathes
      template
    rescue SyntaxError => e
      raise EvalError.wrap(e)
    end
    private :create_template

    # Interpret filename for included templates. Beginning with '/' is the root
    # directory, that is the workdir of the first parser in the tree. All other
    # pathes are treated relative to this parsers workdir.
    def interpret_filename(filename)
      filename.untaint
      if filename[0] == ?/ 
        filename = File.join(rootdir, filename[1, filename.size])
      elsif @workdir
        filename = File.join(@workdir, filename)
      end
      filename
    end
    private :interpret_filename

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
      parser.compile_inner
    end
  
    # The base parsing mode. 
    class Mode
      # Creates a parsing mode for _parser_.
      def initialize(parser)
        @parser = parser
      end

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
          @parser.include_template(scanner[1])
        when scanner.scan(PRIOPEN)
          state.last_open = :PRIOPEN
          @parser.goto_ruby_mode
          state.text2compiled
          state.compiled << 'print(begin '
        when scanner.scan(RAWOPEN)
          state.last_open = :RAWOPEN
          @parser.goto_ruby_mode
          state.text2compiled
          state.compiled << 'print!(begin '
        when scanner.scan(COMOPEN)
          state.last_open = :COMOPEN
          @parser.goto_ruby_mode
          state.text2compiled
          state.compiled << "\n=begin\n"
        when scanner.scan(OPEN)
          state.last_open = :OPEN
          @parser.goto_ruby_mode
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
          @parser.goto_text_mode
          case state.last_open
          when :PRIOPEN
            state.compiled << ' end);'
          when :RAWOPEN
            state.compiled << ' end.to_s);'
          when :COMOPEN
            state.compiled << "\n=end\n"
          else
            state.compiled << ';'
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
        p([ @current_mode.class, state.last_open, state.opened,
          state.compiled_string, scanner.peek(20) ])
      end
    end
    private :debug_output

    def compile_inner  # :nodoc:
      scanner.reset
      until scanner.eos?
        debug_output
        @current_mode.scan
      end
      debug_output
      state.text2compiled
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

    # This class method escapes _string_ in place,
    # by substituting &<>" with their respective html entities.
    def self.escape(string)
      string.to_s.gsub(/[&<>"]/) do |c|
        case c
        when '&' then '&amp;'
        when '<' then '&lt;' 
        when '>' then '&gt;'
        when '"' then '&quot;'
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
