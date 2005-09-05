require 'strscan'

module Flott
# This module includes the Flott::Parser class, that can be used to 
# compile # Flott-Templates to Ruby Proc objects.
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
#  env.instance_variable_set :@name, "Florian"
#  puts fp.evaluate(env)
#
# The output is created by including "header" into "template" with the
# <tt>[<filename]</tt> syntax. <tt>[!@name]</tt> is a shortcut for
# <tt>[print @name]</tt> while <tt>[=@name]</tt> first calls
# Flott::Parser::escape on @name. It's also possible to just print or puts
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


  class FlottException < StandardError
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

  module Delegator
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

  # This class can instantiate environment objects to evaluate Flott Templates
  # in.
  class Environment
    extend Delegator

    # Creates an Environment object, that outputs to _output_. The default
    # ouput stream is STDOUT.
    def initialize(output = STDOUT)
      @output = output
    end

    # Updates the instance variables of this environment with values from
    # _hash_.
    def update(hash)
      hash.each { |name, value| self[name] = value }
    end

    # Returns the instance variable _@name_.
    def [](name)
      name = name.to_s
      name = "@#{name}" unless name[0] == ?@
      instance_variable_get name
    end

    # Sets the instance variable _@name_ to _value_.
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

    delegate :puts, :@output

    delegate :printf, :@output

    delegate :print, :@output

    delegate :putc, :@output
  end

  class Parser < StringScanner
    # This class method escapes _string_ in place,
    # by substituting &<>" with their respective html entities.
    def self.escape(string)
      string = string.to_s
      string.gsub!(/[&<>"]/) do |c|
        case c
        when '&' then '&amp;'
        when '<' then '&lt;' 
        when '>' then '&gt;'
        when '"' then '&quot;'
        else raise "unknown character '#{c}'"
        end
      end
      string
    end

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
      super(source)
    end

    # Creates a Parser object from _filename_
    def self.from_filename(filename)
      dirname = File.dirname(filename)
      workdir = File.expand_path(dirname)
      new(File.read(filename), workdir)
    end

    class ParserState < Struct.new(:mode, :opened, :last_open, :text, :compiled)
      # Transform text mode parts to compiled code parts.
      def text2compiled
        return if text.empty?
        compiled << %{print '}
        compiled.concat(text)
        compiled << %{';}
        text.clear
      end

      # Return the whole compiled code as a string.
      def compiled_string
        compiled.join.untaint
      end
    end

    class Template < Proc
    end

    # Compiles the template source and returns a Proc object to be executed
    # later. This method raises a ParserError exception if source is not
    # _Parser#wellformed?_.
    def compile
      s = ParserState.new(:text, 0, nil, [],
        [ "Template.new { |env| env.instance_eval %q{\n" ])
      compile_inner(s)
      s.compiled << "\n}\n}"
      begin
        eval(s.compiled_string, nil, '(flott)')
      rescue SyntaxError => e
        raise EvalError.wrap(e)
      end
    end
   
    # Include the template _filename_ at the current place 
    def include_template(s, filename)
      filename.untaint
      if filename[0] == ?/ 
        filename = File.join(rootdir, filename[1, filename.size])
      elsif @workdir
        filename = File.join(@workdir, filename)
      end
      if File.readable?(filename)
        s.text2compiled
        source  = File.read(filename)
        workdir = File.dirname(filename) # TODO remember all the file pathes
        parser  = self.class.new(source, workdir)
        parser.parent = self
        parser.compile_inner(s)
      else
        raise CompileError, "Cannot open #{filename} for inclusion!"
      end
    end
    private :include_template

    attr_accessor :parent

    def rootdir
      @rootdir ||= parent ? parent.rootdir : @workdir
    end

    def compile_inner(s)  # :nodoc:
      until eos?
        if s.mode == :text 
          case
          when scan(ESCOPEN)
            s.text << '['
          when scan(INCOPEN)
            s.last_open = :INCOPEN
            include_template(s, self[1])
          when scan(PRIOPEN)
            s.last_open = :PRIOPEN
            s.mode      = :ruby
            s.text2compiled
            s.compiled << 'print Flott::Parser::escape(begin '
          when scan(RAWOPEN)
            s.last_open = :RAWOPEN
            s.mode      = :ruby
            s.text2compiled
            s.compiled << 'print(begin '
          when scan(COMOPEN)
            s.last_open = :COMOPEN
            s.mode      = :ruby
            s.text2compiled
            s.compiled << "\n=begin\n"
          when scan(OPEN)
            s.last_open = :OPEN
            s.mode      = :ruby
            s.text2compiled
          when scan(CLOSE)
            s.text << self[0]
          when scan(TEXT)
            s.text << self[0].gsub(/'/, %{\\\\'}) if self[0]
          else
            raise CompileError, "unknown tokens '#{peek(40)}'"
          end
        elsif s.mode == :ruby
          case
          when scan(CLOSE) && s.opened == 0
            s.mode = :text
            case s.last_open
            when :PRIOPEN
              s.compiled << ' end);'
            when :RAWOPEN
              s.compiled << ' end.to_s);'
            when :COMOPEN
              s.compiled << "\n=end\n"
            else
              s.compiled << ';'
            end
            s.last_open = nil
          when scan(ESCCLOSE)
            s.compiled << self[0]
          when scan(CLOSE) && opened != 0
            s.opened -= 1
            s.compiled << self[0]
          when scan(ESCOPEN)
            s.opened += 1
            s.compiled << self[0]
          when scan(OPEN)
            s.opened += 1
            s.compiled << self[0]
          when scan(TEXT)
            s.compiled << self[0]
          else
            raise CompileError, "unknown tokens '#{peek(40)}'"
          end
        else
          raise CompileError, "unknown state '#{s.mode}'!"
        end
      end
      s.text2compiled
    end
    protected :compile_inner

    # First compiles the source template and evaluates it in the environment
    # env. If no environment is given, a newly created environment is used.
    def evaluate(env = Environment.new, &block)
      env.instance_eval(&block) if block
      compile.call(env)
      self
    rescue SyntaxError => e
      raise CallError.wrap(e)
    end

    # The already compiled ruby code is evaluated in the environment env.
    # If no environment is given, a newly created environment is used.
    def self.evaluate(compiled, env = Environment.new, &block)
      env.instance_eval(&block) if block
      compiled.call(env)
      self
    rescue SyntaxError => e
      raise CallError.wrap(e)
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
