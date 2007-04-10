#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_Flott < Test::Unit::TestCase
  include Flott

  def assert_template_equal(expected, template, hash = {})
    output = ''
    env = Environment.new(output)
    env.update hash
    parser = Parser.new(template)
    parser.evaluate(env)
    assert_equal expected, output
  end

  def test_error
    assert_raises(CallError) do
      Parser.new('<bla>[= [^/bla>').evaluate
    end
    assert_raises(CallError) do
      Parser.new('<bla>[^/bla>').evaluate
    end
    assert_raises(CompileError) do
      Parser.new('<bla>[^does_not_exist]</bla>').evaluate
    end
  end

  def test_for_errors
    assert_template_equal 'puts "\n"', 'puts "\n"'
    assert_template_equal "123\n", '[print [1, 2, "3"], "\n" ]'
    assert_template_equal "a\b", '[print "a\b" ]'
    assert_template_equal "a\b", '[print "a\\b" ]'
    assert_template_equal "a\b", '[print "a\\\b" ]'
    assert_template_equal "a\b", '[print "a\\\\b" ]'
    assert_template_equal "puts [1, 2, '3']", "puts \\[1, 2, '3']"
    assert_template_equal "puts {1, 2}", "puts {1, 2}"
    assert_template_equal "puts {1, 2}", "puts {1, [=1+1]}"
    assert_template_equal "puts {'1', 2}", "puts {'1', [=1+1]}"
    assert_template_equal "lambda { |x| '", "lambda { |x| '"
    assert_template_equal "}", "}"
    assert_template_equal "{}}", "{}}"
    assert_template_equal "", "[lambda {}]"
    assert_template_equal "foo", "[=lambda {:foo}.call]"
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
    assert_template_equal("false\n\ntrue\n", <<__EOT)
[=respond_to? :foobar]
[=fun :foobar do end]
[=respond_to? :foobar]
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
    include Flott::EnvironmentMixin

    # or explicitly:
    #def initialize(*)
    #  super
    #end
  end

  def test_my_environment
    env = MyEnvironment.new
    assert_kind_of Array, env
    assert_kind_of Flott::EnvironmentMixin, env
  end

  def test_p
    assert_template_equal %Q'AAA[1, :foo, &quot;bar&quot;]\nBBB', 'AAA[p [1, :foo, "bar"]]BBB'
  end

  def test_p_bang
    assert_template_equal %Q'AAA[1, :foo, "bar"]\nBBB', 'AAA[p! [1, :foo, "bar"]]BBB'
  end

  def test_pp
    assert_template_equal %Q'AAA[1, :foo, &quot;bar&quot;]\nBBB', 'AAA[pp [1, :foo, "bar"]]BBB'
  end

  def test_pp_bang
    assert_template_equal %Q'AAA[1, :foo, "bar"]\nBBB', 'AAA[pp! [1, :foo, "bar"]]BBB'
  end

  def test_puts_bang
    assert_template_equal %Q'AAA<BBB>\nCCC', 'AAA[puts! "<BBB>"]CCC'
  end

  def test_puts
    assert_template_equal %Q'AAA&lt;BBB&gt;\nCCC', 'AAA[puts "<BBB>"]CCC'
  end

  def test_putc_bang
    assert_template_equal %Q'AAA<CCC', 'AAA[putc! "<BBB>"]CCC'
    assert_template_equal %Q'AAA<CCC', 'AAA[putc! ?<]CCC'
  end

  def test_putc
    assert_template_equal %Q'AAA&lt;CCC', 'AAA[putc "<BBB>"]CCC'
    assert_template_equal %Q'AAA&lt;CCC', 'AAA[putc ?<]CCC'
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

  def test_no_newline
    assert_template_equal "a\nb\nc", "a\n[print 'b']\nc"
    assert_template_equal "ab\nc", "a  [-print 'b']\nc"
    assert_template_equal "a  bc", "a  [print 'b'-]\nc"
    assert_template_equal "abc", "a  [-print 'b'-]\nc"
    assert_template_equal <<DST, <<SRC
<ul>
  <li>1</li>
  <li>2</li>
  <li>3</li>
</ul>
DST
<ul>
  [-3.times do |i|-]
  <li>[=i + 1]</li>
  [-end-]
</ul>
SRC
  end
end
  # vim: set et sw=2 ts=2:
