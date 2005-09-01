#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_Flott < Test::Unit::TestCase
  include Flott

  def setup
    @parser = Parser.new
    @template = File.read(File.join(
      File.dirname(__FILE__), 'templates', 'template'))
  end

  def test_foo
    parser = Parser.new
    assert_kind_of Parser, parser
  end

  def test_compile
    assert @parser.compile(@template)
    assert @parser.wellformed?(@template)
  end

  def test_execute
    expected =<<__EOT
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
 <head>
  <title>Hello Florian!</title>
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
 </head>
 <body>

 <h1>Hello Florian[!</h1>
 
     <i>Hello Florian]!</i>
   
     <b>Hello Florian]!</b>
   
     <i>Hello Florian]!</i>
   
     <b>Hello Florian]!</b>
   
     <i>Hello Florian]!</i>
   
     <b>Hello Florian]!</b>
   
 </body>
</html>
__EOT
    env = Object.new
    env.instance_variable_set :@name, 'Florian'
    output = ''
    $stdout = StringIO.new(output)
    @parser.evaluate(@template, env) 
    assert_equal(expected, output)
    output = ''
    $stdout = StringIO.new(output)
    compiled = @parser.compile(@template)
    Parser.evaluate(compiled, env)
    assert_equal(expected, output)
  end

  def test_error
    assert_raises(Parser::CompileError) do
      @parser.evaluate('<bla>[= [</bla>')
    end
    assert_raises(Parser::CallError) do
      @parser.evaluate('<bla>[</bla>')
    end
    assert_raises(Parser::EvalError) do
      @parser.evaluate('lambda { |x| ')
    end
  end
end
  # vim: set et sw=2 ts=2:
