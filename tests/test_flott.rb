require 'test_helper'
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
    if RUBY_VERSION =~ /\A1.[0-8]/
      assert_template_equal "123\n", '[print [1, 2, "3"], "\n" ]'
    else
      assert_template_equal "[1, 2, &quot;3&quot;]\n", '[print [1, 2, "3"], "\n" ]'
    end
    assert_template_equal "a\b", '[print "a\b" ]' # 1
    assert_template_equal "a\b", '[print "a\\b" ]' # 2
    assert_template_equal "a\\b", '[print "a\\\b" ]' # 3
    assert_template_equal "a\\b", '[print "a\\\\b" ]' # 4
    assert_template_equal "a\\\b", '[print "a\\\\\b" ]' # 5
    assert_template_equal "a\\\b", '[print "a\\\\\\b" ]' # 6
    assert_template_equal "a\\\\b", '[print "a\\\\\\\\b" ]' # 7
    assert_template_equal "a\\\\\b", '[print "a\\\\\\\\\b" ]' # 8
    assert_template_equal "a\\\\\b", '[print "a\\\\\\\\\\b" ]' # 9
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
      env.instance_variables.map { |x| x.to_s }.sort
    env[:foo] = :foo
    assert_equal ["@__escape__", "@__output__", "@foo"].sort,
      env.instance_variables.map { |x| x.to_s }.sort
    assert_equal env[:foo], :foo
    assert_equal env[:@foo], :foo
    env[:@bar] = :bar
    assert_equal ["@__escape__", "@__output__", "@bar", "@foo"].sort,
      env.instance_variables.map { |x| x.to_s }.sort
    assert_equal env[:bar], :bar
    assert_equal env[:@bar], :bar
    env.update({ :baz => :baz })
    assert_equal ["@__escape__", "@__output__", "@bar", "@baz", "@foo"].sort,
      env.instance_variables.map { |x| x.to_s }.sort
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

  def test_minus
    assert_template_equal "a\nb\nc", "a\n[print 'b']\nc"
    assert_template_equal "a \t b \t c", "a \t [print 'b'] \t c"
    assert_template_equal "a\nb\nc", "a\n \t [-print 'b']\nc"
    assert_template_equal "a\nb \t c", "a\n \t [-print 'b'] \t c"
    assert_template_equal "a\n \t bc", "a\n \t [print 'b'-] \t \nc"
    assert_template_equal "abc", "a \t [-print 'b'-]\nc"
    assert_template_equal "a\n&lt;bc", "a\n \t [-='<b'-] \t \nc"
    assert_template_equal "a\n<bc", "a\n \t [-!'<b'-] \t \nc"
    assert_template_equal "a\nc", "a\n \t [-#'<b'-] \t \nc"
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

  def test_function
    assert_template_equal "AAABB", "[=function :multiple do |x, n| x * n end;multiple 'A', 3][=multiple 'B', 2]"
    assert_template_equal "AAABB", "[=function :multiple, :memoize => 3 do |x, n| x * n end;multiple 'A', 3][=multiple 'B', 2]"
  end
end
