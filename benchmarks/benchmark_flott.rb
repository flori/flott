#!/usr/bin/env ruby

require 'bullshit'

class BC_Flott < Bullshit::TimeCase
  warmup      true
  duration    10

  require 'erb'

  require 'flott'
  include Flott

  begin
    require 'kashmir'
  rescue LoadError
  end

  begin
    require 'eruby'
  rescue LoadError
  end

  begin
    require "amrita/template"
    include Amrita
  rescue LoadError
  end
 
  LENGTH = 100
  
  def setup
    @output = String.new 
  end

  def output_reset
    @output.empty? and raise "No output generated!"
    @output.replace ''
  end

  def setup_benchmark_flott
    GC.start
    @env    = Environment.new(@output)
    par = Parser.new( %'AAAAA[!3.141 ** 2]AAAAA\n' * LENGTH)
    @flott  = par.compile
    puts par.state.compiled_string
  end

  def benchmark_flott
    @flott.evaluate(@env)
    output_reset
  end

  def setup_benchmark_flott_e
    GC.start
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[=3.141 ** 2]AAAAA\n' * LENGTH).compile
  end

  def benchmark_flott_e
    @flott.evaluate(@env)
    output_reset
  end

  def setup_benchmark_erb
    GC.start
    @erb    = ERB.new(    %'AAAAA<%=3.141 ** 2%>AAAAA\n' * LENGTH, 0, '%<>')
  end

  def benchmark_erb
    @output = @erb.result
    output_reset
  end

  if defined? Kashmir
    def setup_benchmark_kashmir
      GC.start
      @kashmir = Kashmir.new(%'AAAAA^(3.141 ** 2)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir
      @output = @kashmir.expand(Object.new)
    end

    def setup_benchmark_kashmir_e
      GC.start
      @kashmir = Kashmir.for_XML(%'AAAAA^(3.141 ** 2)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir_e
      @output = @kashmir.expand(Object.new)
    end
  end

  if defined? ERuby
    def setup_benchmark_eruby
      GC.start
      require 'stringio'
      ec = ERuby::Compiler.new
      @eruby = ec.compile_string(%'AAAAA<%=3.141 ** 2%>AAAAA\n' * LENGTH)
      $stdout = StringIO.new(@output)
    end

    def benchmark_eruby
      eval(@eruby)
      output_reset_eruby
    end

    def output_reset_eruby
      output_reset
      $stdout = StringIO.new(@output)
    end
  end

  if defined? Amrita
    def setup_benchmark_amrita
      GC.start
      @amrita = TemplateText.new(%'AAAAA<div id="test"></div>AAAAA\n' * LENGTH)
    end

    def benchmark_amrita
      @amrita.expand(@output, { :test => 3.141 ** 2 })
      output_reset
    end
  end

  compare :flott, :flott_e, :erb, :erb_e, :kashmir, :kashmir_e, :eruby, :amrita
end
