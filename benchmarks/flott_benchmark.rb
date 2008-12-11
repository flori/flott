#!/usr/bin/env ruby

require 'bullshit'

class FlottBenchmark < Bullshit::RepeatCase
  warmup      true

  truncate_data do
    window_size 50
  end

  iterations 1000

  output_dir File.join(File.dirname(__FILE__), 'data')
  data_file  yes

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
    require "amrita2"
    include Amrita2
  rescue LoadError
  end
 
  LENGTH = 100
  
  def setup
    @output = String.new 
  end

  def common_output_reset
    @output.empty? and raise "No output generated!"
    @output.replace ''
  end

  def setup_flott
    @env    = Environment.new(@output)
    par     = Parser.new( %'AAAAA[!3.141 ** 2]AAAAA\n' * LENGTH)
    @flott  = par.compile
  end

  def benchmark_flott
    @flott.evaluate(@env)
  end

  alias reset_flott common_output_reset

  def setup_flott_escaped
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[=3.141 ** 2]AAAAA\n' * LENGTH).compile
  end

  def benchmark_flott_escaped
    @flott.evaluate(@env)
  end

  alias reset_flott_escaped common_output_reset

  def setup_erb
    @erb    = ERB.new(    %'AAAAA<%=3.141 ** 2%>AAAAA\n' * LENGTH, 0, '%<>')
  end

  def benchmark_erb
    @output = @erb.result
  end

  alias reset_erb common_output_reset

  if defined? Kashmir
    def setup_kashmir
      @kashmir = Kashmir.new(%'AAAAA^(3.141 ** 2)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir
      @output = @kashmir.expand(Object.new)
    end

    alias reset_kashmir common_output_reset

    def setup_kashmir_escaped
      @kashmir = Kashmir.for_XML(%'AAAAA^(3.141 ** 2)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir_escaped
      @output = @kashmir.expand(Object.new)
    end

    alias reset_kashmir_escaped common_output_reset
  end

  if defined? ERuby
    def setup_eruby
      require 'stringio'
      ec = ERuby::Compiler.new
      @eruby = ec.compile_string(%'AAAAA<%=3.141 ** 2%>AAAAA\n' * LENGTH)
      $stdout = StringIO.new(@output)
    end

    def benchmark_eruby
      eval(@eruby)
    end

    alias reset_eruby common_output_reset
  end

  if defined? Amrita2
    def setup_amrita
      @amrita = Template.new(%'AAAAA<span am:src="test"></span>AAAAA\n' * LENGTH)
    end

    def benchmark_amrita
      @output = @amrita.render_with(:test => 3.141 ** 2)
    end

    alias reset_amrita common_output_reset
  end
end
