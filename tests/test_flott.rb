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
  @expected2 =<<__EOT.gsub(/: .*templates/, ': @{prefix}')
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
 <head>
  <title>Hello !</title>
  <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-15">
 </head>
 <body>

Workdir before (template2): @{prefix}
Workdir 1 (included): @{prefix}/subdir
Toplevel
Workdir (toplevel): @{prefix}

Workdir 2 (included): @{prefix}/subdir
Workdir (included2): @{prefix}/subdir/subdir2

Workdir 3 (included): @{prefix}/subdir
Workdir (included3): @{prefix}/subdir

Workdir 4 (included): @{prefix}/subdir
Toplevel
Workdir (toplevel): @{prefix}/subdir

Workdir 5 (included): @{prefix}/subdir

Workdir after (template2): @{prefix}
</body>
</html>
__EOT
    workdir = File.join(File.dirname(__FILE__), 'templates')
    @parser = Parser.new(File.read(File.join(workdir, 'template')), workdir)
    @parser2 = Parser.from_filename(File.join(workdir, 'template2'))
  end

  def assert_template_equal(expected, template, hash = {})
    output = ''
    env = Environment.new(output)
    env.update hash
    parser = Parser.new(template)
    parser.evaluate(env)
    assert_equal expected, output
  end

  def test_kind
    assert_kind_of Parser, @parser
    assert_kind_of Parser, @parser2
  end

  def test_compile
    assert @parser.compile
  end

  def test_compile2
    assert @parser2.compile
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
    assert_template_equal 'puts "\n"', 'puts "\n"'
  end

  def test_dynamic_include
    output = ''
    env = Environment.new(output)
    @parser2.evaluate(env)
    output.gsub!(/: .*templates/, ': @{prefix}')
    assert_equal @expected2, output
  end

  def test_fun
    assert_template_equal("\nAAA3628800BBB\n", <<__EOT)
[fun :fac do |n|
  if n < 2
    1
  else
    n * fac(n - 1)
  end
end]
AAA[=fac(10)]BBB
__EOT
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
    env[:@bar] = :bar
    assert_equal ["@__escape__", "@__output__", "@bar", "@foo"].sort,
      env.instance_variables.sort
    assert_equal env[:bar], :bar
    assert_equal env[:@bar], :bar
    env.update({ :baz => :baz })
    assert_equal ["@__escape__", "@__output__", "@bar", "@baz", "@foo"].sort,
      env.instance_variables.sort
    assert_equal env[:baz], :baz
    assert_equal env[:@baz], :baz
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

  def test_p
    assert_template_equal %Q'AAA[1, :foo, "bar"]\nBBB', 'AAA[p [1, :foo, "bar"]]BBB'
  end

  def test_pp
    assert_template_equal %Q'AAA[1, :foo, "bar"]\nBBB', 'AAA[pp [1, :foo, "bar"]]BBB'
  end

  def test_puts_bang
    assert_template_equal %Q'AAA<BBB>\nCCC', 'AAA[puts! "<BBB>"]CCC'
  end

  def test_puts
    assert_template_equal %Q'AAA&lt;BBB&gt;\nCCC', 'AAA[puts "<BBB>"]CCC'
  end

  def test_printf_bang
    assert_template_equal %Q'AAA<B42BB>CCC', 'AAA[printf! "<B%xBB>", 66]CCC'
  end

  def test_printf
    assert_template_equal %Q'AAA&lt;B42BB&gt;CCC', 'AAA[printf "<B%xBB>", 66]CCC'
  end

  def test_print_bang
    assert_template_equal %Q'AAA<BBB>CCC', 'AAA[print! "<BBB>"]CCC'
  end

  def test_print
    assert_template_equal %Q'AAA&lt;BBB&gt;CCC', 'AAA[print "<BBB>"]CCC'
  end

  def test_write_bang
    assert_template_equal %Q'AAA<BBB>CCC', 'AAA[write! "<BBB>"]CCC'
  end

  def test_write
    assert_template_equal %Q'AAA&lt;BBB&gt;CCC', 'AAA[write "<BBB>"]CCC'
  end
end
  # vim: set et sw=2 ts=2:
