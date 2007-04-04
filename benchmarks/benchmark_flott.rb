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

  def reset
    @output.empty? and raise "No output generated!"
    @output.replace ''
  end
  
  def setup_benchmark_flott
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[!Time.now]AAAAA\n' * LENGTH).compile
  end

  def benchmark_flott
    @flott.evaluate(@env)
  end

  def setup_benchmark_flott_e
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[=Time.now]AAAAA\n' * LENGTH).compile
  end

  def benchmark_flott_e
    @flott.evaluate(@env)
  end

  def setup_benchmark_erb
    @erb    = ERB.new(    %'AAAAA<%=Time.now%>AAAAA\n' * LENGTH, 0, '%<>')
  end

  def benchmark_erb
    @output = @erb.result
  end

  if defined? Kashmir
    def setup_benchmark_kashmir
      @kashmir = Kashmir.new(%'AAAAA^(Time.now)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir
      @output = @kashmir.expand(Object.new)
    end

    def setup_benchmark_kashmir_e
      @kashmir = Kashmir.for_XML(%'AAAAA^(Time.now)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir_e
      @output = @kashmir.expand(Object.new)
    end
  end

  if defined? ERuby
    def setup_benchmark_eruby
      require 'stringio'
      ec = ERuby::Compiler.new
      @eruby = ec.compile_string(%'AAAAA<%=Time.now%>AAAAA\n' * LENGTH)
      $stdout = StringIO.new(@output)
    end

    def reset_benchmark_eruby
      reset
      $stdout = StringIO.new(@output)
    end
    
    def benchmark_eruby
      eval(@eruby)
    end
  end

  if defined? Amrita
    def setup_benchmark_amrita
      @amrita = TemplateText.new(%'AAAAA<div id="time"></div>AAAAA\n' * LENGTH)
    end

    def benchmark_amrita
      @amrita.expand(@output, { :time => Time.now })
    end
  end

  compare :flott, :flott_e, :erb, :erb_e, :kashmir, :eruby, :amrita
end
