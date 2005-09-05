#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_Flott < Test::Unit::TestCase
  include Flott

  def setup
    @expected =<<__EOT
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
    workdir = File.join(File.dirname(__FILE__), 'templates')
    @parser = Parser.new(File.read(File.join(workdir, 'template')), workdir)
    @parser2 = Parser.from_filename(File.join(workdir, 'template'))
  end

  def test_foo
    assert_kind_of Parser, @parser
  end

  def test_compile
    assert @parser.compile
    assert @parser.wellformed?
  end

  def test_execute
    env = Object.new
    env.instance_variable_set :@name, 'Florian'
    output = ''
    $stdout = StringIO.new(output)
    @parser.evaluate(env) 
    assert_equal(@expected, output)
  end

  def test_compile
    env = Object.new
    env.instance_variable_set :@name, 'Florian'
    output = ''
    $stdout = StringIO.new(output)
    compiled = @parser.compile
    Parser.evaluate(compiled, env)
    assert_equal(@expected, output)
  end

  def test_error
    assert_raises(CallError) do
      Parser.new('<bla>[= [</bla>').evaluate
    end
    assert_raises(CallError) do
      Parser.new('<bla>[</bla>').evaluate
    end
    assert_raises(EvalError) do
      Parser.new('lambda { |x| ').evaluate
    end
  end
end
  # vim: set et sw=2 ts=2:
