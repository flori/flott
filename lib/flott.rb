require 'strscan'

module Flott
  class FlottException < StandardError
    def self.wrap(exception)
      wrapper = new(exception.message)
      wrapper.set_backtrace exception.backtrace
      wrapper
    end
  end

  class Parser < StringScanner
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

    # This class method escapes <code>string</code> in place,
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

    # Creates a Parser object. <code>workdir</code> is the directory, on which
    # [<file] inclusions are based.
    def initialize(source, workdir = nil)
      if workdir
        @workdir = File.expand_path(workdir)
      else
        @workdir = File.expand_path(Dir.pwd)
      end
      super(source)
    end

    class ParserState < Struct.new(:mode, :opened, :last_open, :text, :compiled)
      def text2compiled
        return if text.empty?
        compiled << %{print '}
        compiled.concat(text)
        compiled << %{';}
        text.clear
      end

      def compiled_string
        compiled.join.untaint
      end
    end

    # Compiles the template source and returns a Proc object to be executed
    # later. This method raises a ParserError exception if source is not
    # <code>Parser#wellformed?</code>.
    def compile
      s = ParserState.new(:text, 0, nil, [],
        [ "lambda { |env| env.instance_eval %q{\n" ])
      compile_inner(s)
      s.compiled << "\n}\n}"
      begin
        eval(s.compiled_string, nil, '(flott)')
      rescue SyntaxError => e
        raise EvalError.wrap(e)
      end
    end
    
    def include_template(s, filename)
      filename.untaint
      if @workdir
        filename = File.join(@workdir, filename)
      end
      if File.readable?(filename)
        s.text2compiled
        source = File.read(filename)
        workdir = File.dirname(filename)
        parser = self.class.new(source, workdir)
        parser.compile_inner(s)
      else
        raise CompileError, "Cannot open #{filename} for inclusion!"
      end
    end

    def compile_inner(s)
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
    def evaluate(env = Object.new)
      compile.call(env)
      self
    rescue SyntaxError => e
      raise CallError.wrap(e)
    end

    # The already compiled ruby code is evaluated in the environment env.
    # If no environment is given, a newly created environment is used.
    def self.evaluate(compiled, env = Object.new)
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
end

if $0 == __FILE__
  filename = ARGV.shift
  parser = if filename
    Flott::Parser.new(File.read(filename), File.dirname(filename))
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
