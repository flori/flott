#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_Flott < Test::Unit::TestCase
  include Flott
  Flott.debug = false

  def setup
    @output = StringIO.new('')
    @expected =<<__EOT
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
 <head>
  <title>Hello Flor&lt;i&gt;an!</title>
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
 </head>
 <body>

 <h1>Hello Flor&lt;i&gt;an[!</h1>
 
     <i>Hello Flor<i>an]!</i>
   
     <b>Hello Flor&lt;i&gt;an]!</b>
   
     <i>Hello Flor<i>an]!</i>
   
     <b>Hello Flor&lt;i&gt;an]!</b>
   
     <i>Hello Flor<i>an]!</i>
   
     <b>Hello Flor&lt;i&gt;an]!</b>
   
 
 </body> ]
</html>
__EOT
    workdir = File.join(File.dirname(__FILE__), 'templates')
    @parser = Parser.new(File.read(File.join(workdir, 'template')), workdir)
    @parser2 = Parser.from_filename(File.join(workdir, 'template2'))
  end
=begin
  def test_kind
    assert_kind_of Parser, @parser
    assert_kind_of Parser, @parser2
  end

  def test_compile
    assert @parser.compile
  end

  def test_wellformed
    assert @parser.wellformed?
  end

  def test_compile2
    assert @parser2.compile
  end

  def test_wellformed2
    assert @parser2.wellformed?
  end

  def test_execute
    env = Environment.new(@output)
    env[:name] = 'Flor<i>an'
    @parser.evaluate(env) 
    assert_equal(@expected, @output.string)
    @output.rewind
    @parser.evaluate(env) 
    assert_equal(@expected, @output.string)
  end

  def test_compile_evaluate
    env = Environment.new(@output)
    env[:@name] = 'Flor<i>an'
    compiled = @parser.compile
    Parser.evaluate(compiled, env)
    assert_equal(@expected, @output.string)
    @output.rewind
    Parser.evaluate(compiled, env)
    assert_equal(@expected, @output.string)
  end

  def test_execute2
    env = Environment.new(@output)
    @parser2.evaluate(env)
    assert_match /Toplevel/, @output.string
    @output.rewind
    @parser2.evaluate(env)
    assert_match /Toplevel/, @output.string
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
    assert_raises(CompileError) do
      Parser.new('<bla>[<does_not_exist]</bla>').evaluate
    end
  end

  def test_errors
    env = Environment.new(@output)
    tmpl = 'puts "\n"'
    assert Parser.new(tmpl).evaluate(env)
    assert_equal(tmpl, @output.string)
  end
=end
  def test_dynamic_include
    env = Environment.new(@output)
    @parser2.evaluate(env)
    warn @output.string
  end
end
  # vim: set et sw=2 ts=2:
