#!/usr/bin/env ruby

require 'bullshit'

class BC_Flott < Bullshit::RepeatCase
  def setup
    self.repeat = 2_000
    @part       = 'A' * 100
    @str        = ''
    @ary        = []
  end

  def benchmark_concat
    @repeat.times { @str << @part  }
  end

  def benchmark_join
    @repeat.times { @ary << @part }
    @ary.join
  end

  def benchmark_append
    @repeat.times { @str += @part }
  end
end
