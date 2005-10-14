#!/usr/bin/env ruby

require 'bullshit'
require 'flott'
require 'erb'

class BC_FlottTime < Bullshit::TimeCase
  include Flott

  def setup
    @time   = 10
    @null   = File.new('/dev/null', 'w')
    @flott  = Parser.new('AAAAA[!Time.now]AAAAA' * 100)
    @erb    = ERB.new('AAAAA<%=Time.now%>AAAAA' * 100, 0, '%<>')
    @env    = Environment.new(@null)
  end

  def benchmark_flott
    @flott.evaluate(@env)
  end

  def benchmark_erb
    @erb.result
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
