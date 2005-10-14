#!/usr/bin/env ruby

require 'bullshit'
require 'flott'
require 'erb'

class BC_FlottTime < Bullshit::TimeCase
  include Flott

  begin
    require 'kashmir'
  rescue LoadError
  end
  
  def setup
    @time   = 10
    #@null   = File.new('/dev/null', 'w')
    require 'stringio'
    @null    = StringIO.new
    #STDOUT.reopen @null
    @flott  = Parser.new( %'AAAAA[!Time.now]AAAAA' * 10).compile
    @erb    = ERB.new(    %'AAAAA<%=Time.now%>AAAAA' * 10, 0, '%<>')
    @env    = Environment.new(@null)
    if defined? Kashmir
      @kashmir = Kashmir.new(%'AAAAA^(Time.now)AAAAA' * 10)
    end
  end

  def benchmark_flott
    @flott.evaluate(@env)
  end

#  def benchmark_erb
#    @erb.run
#  end

if defined? Kashmir
  def benchmark_kashmir
    @kashmir.expand(Object.new)
  end
end
end

=begin
class BC_FlottRepeat < Bullshit::RepeatCase
  def setup
    @repeat     = 10
    @how_many   = 100
    @part       = 'A' * 100
    @str        = ''
    @ary        = []
  end

  def benchmark_concat
    @how_many.times { @str << @part }
  end

  def benchmark_join
    @how_many.times { @ary << @part }
    @ary.join
  end

  def benchmark_append
    @how_many.times { @str += @part }
  end
end

class BC_FlottTime < Bullshit::TimeCase
  def setup
    @time       = 1
    @how_many   = 100
    @part       = 'A' * 100
    @str        = ''
    @ary        = []
  end

  def benchmark_concat
    @how_many.times { @str << @part }
  end

  def benchmark_join
    @how_many.times { @ary << @part }
    @ary.join
  end

  def benchmark_append
    @how_many.times { @str += @part }
  end
end
=end
