#!/usr/bin/env ruby

require 'bullshit'

class BC_FlottTime < Bullshit::TimeCase
  self.rehearsal  = true
  repeat_duration 10

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
 
  LENGTH = 10
  
  def setup
    @output = String.new 
  end

  def reset
    @output.empty? and raise "No output generated!"
    @output.replace ''
  end
  
  def setup_benchmark_flott
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[!Time.now]AAAAA' * LENGTH).compile
  end

  def benchmark_flott
    @flott.evaluate(@env)
  end

  def setup_benchmark_flott_escaped
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[=Time.now]AAAAA' * LENGTH).compile
  end

  def benchmark_flott_escaped
    @flott.evaluate(@env)
  end

  def setup_benchmark_erb
    @erb    = ERB.new(    %'AAAAA<%=Time.now%>AAAAA' * LENGTH, 0, '%<>')
  end

  def benchmark_erb
    @output = @erb.result
  end

  if defined? Kashmir
    def setup_benchmark_kashmir
      @kashmir = Kashmir.new(%'AAAAA^(Time.now)AAAAA' * LENGTH)
    end

    def benchmark_kashmir
      @output = @kashmir.expand(Object.new)
    end
  end

  if defined? ERuby
    def setup_benchmark_eruby
      require 'stringio'
      ec = ERuby::Compiler.new
      @eruby = ec.compile_string(%'AAAAA<%=Time.now%>AAAAA' * LENGTH)
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
      @amrita = TemplateText.new(%'AAAAA<div id="time"></div>AAAAA' * LENGTH)
    end

    def benchmark_amrita
      @amrita.expand(@output, { :time => Time.now })
    end
  end
end
