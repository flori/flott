#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_Flott < Test::Unit::TestCase
  include Flott
  Flott.debug = false

  def setup
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
  @expected2 =<<__EOT
    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
 <head>
  <title>Hello !</title>
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
 </head>
 <body>
Workdir before (template2): /home/flori/cvs/ruby/flott/tests/templates
Workdir 1 (included): /home/flori/cvs/ruby/flott/tests/templates/subdir
Toplevel
Workdir (toplevel): /home/flori/cvs/ruby/flott/tests/templates

Workdir 2 (included): /home/flori/cvs/ruby/flott/tests/templates/subdir
Workdir (included2): /home/flori/cvs/ruby/flott/tests/templates/subdir/subdir2

Workdir 3 (included): /home/flori/cvs/ruby/flott/tests/templates/subdir
Workdir (included3): /home/flori/cvs/ruby/flott/tests/templates/subdir

Workdir 4 (included): /home/flori/cvs/ruby/flott/tests/templates/subdir
Toplevel
Workdir (toplevel): /home/flori/cvs/ruby/flott/tests/templates/subdir

Workdir 5 (included): /home/flori/cvs/ruby/flott/tests/templates/subdir

Workdir after (template2): /home/flori/cvs/ruby/flott/tests/templates
</body>
</html>
__EOT
    workdir = File.join(File.dirname(__FILE__), 'templates')
    @parser = Parser.new(File.read(File.join(workdir, 'template')), workdir)
    @parser2 = Parser.from_filename(File.join(workdir, 'template2'))
  end

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
    output = StringIO.new('')
    env = Environment.new(output)
    env[:name] = 'Flor<i>an'
    @parser.evaluate(env) 
    assert_equal(@expected, output.string)
    output.rewind
    @parser.evaluate(env) 
    assert_equal(@expected, output.string)
  end

  def test_compile_evaluate
    output = StringIO.new('')
    env = Environment.new(output)
    env[:@name] = 'Flor<i>an'
    compiled = @parser.compile
    Parser.evaluate(compiled, env)
    assert_equal(@expected, output.string)
    output.rewind
    Parser.evaluate(compiled, env)
    assert_equal(@expected, output.string)
  end

  def test_execute2
    output = StringIO.new('')
    env = Environment.new(output)
    @parser2.evaluate(env)
    assert_match /Toplevel/, output.string
    output.rewind
    @parser2.evaluate(env)
    assert_match /Toplevel/, output.string
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

  def test_for_errors
    output = ''
    env = Environment.new(output)
    tmpl = 'puts "\n"'
    assert Parser.new(tmpl).evaluate(env)
    assert_equal(tmpl, output)
  end

  def test_dynamic_include
    output = ''
    env = Environment.new(output)
    @parser2.evaluate(env)
    assert @expected2, output
  end

  def test_fun
    output = ''
    env = Environment.new(output)
    parser = Parser.new(<<__EOT)
[fun :f do |n|
  if n < 2
    1
  else
    n * f(n - 1)
  end
end]
[=f(10)]
__EOT
    parser.evaluate(env)
    assert_equal "\n3628800\n", output
  end

  def test_environment_instance_variables
    env = Environment.new
    env.output = output = ''
    assert_equal ["@__escape__", "@__output__"].sort,
      env.instance_variables.sort
    env[:foo] = :foo
    assert_equal ["@__escape__", "@__output__", "@foo"].sort,
      env.instance_variables.sort
    assert_equal env[:foo], :foo
    assert_equal env[:@foo], :foo
    env.update({ :bar => :bar })
    assert_equal ["@__escape__", "@__output__", "@bar", "@foo"].sort,
      env.instance_variables.sort
    assert_equal env[:bar], :bar
    assert_equal env[:@bar], :bar
    assert_equal env[:__output__], output
    assert_equal env.output, output
  end

  class MyEnvironment < Array
    include Flott::EnvironmentExtension

    def initialize(*)
      environment_initialize
      super
    end
  end

  def test_my_environment
    env = MyEnvironment.new
    assert_kind_of Array, env
    assert_kind_of Flott::EnvironmentExtension, env
  end
end
  # vim: set et sw=2 ts=2:
