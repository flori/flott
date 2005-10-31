#!/usr/bin/env ruby

require 'bullshit'

module MyCases
  def setup
    @n    = 1_000
  end

  def setup_benchmark_for
    @test_setup = true
  end
  
  def benchmark_for
    f = 1
    for i in 1 .. @n
      f *= i
    end
    f
  end

  def teardown_benchmark_for
    raise "test_setup not set" unless @test_setup
  end

  def benchmark_times
    f = i = 1
    @n.times do
      f *= i
      i += 1
    end
    f
  end

  def benchmark_while
    f = i = 1
    while i < @n
      f *= i
      i += 1
    end
    f
  end

  def benchmark_inject
    (1..@n).inject(1) { |f, x| f * x }
  end
end

class BC_TestRepeat < Bullshit::RepeatCase
  repeat_iterations 250

  include MyCases
end

class BC_TestTime < Bullshit::TimeCase
  repeat_duration 3

  include MyCases
end

