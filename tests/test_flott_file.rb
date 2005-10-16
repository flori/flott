#!/usr/bin/env ruby

require 'test/unit'
require 'flott'
require 'stringio'

class TC_FlottFile < Test::Unit::TestCase
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

  def test_dynamic_include
    output = ''
    env = Environment.new(output)
    @parser2.evaluate(env)
    output.gsub!(/: .*templates/, ': @{prefix}')
    assert_equal @expected2, output
  end

end
