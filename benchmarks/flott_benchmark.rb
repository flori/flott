#!/usr/bin/env ruby

require 'bullshit'
require 'tins/xt'

class FlottBenchmark < Bullshit::RepeatCase
  warmup      true

  truncate_data do
    window_size 50
  end

  autocorrelation do
    alpha_level 0.05
    max_lags    50
    file        yes
  end

  iterations 1000

  output_dir File.join(File.dirname(__FILE__), 'data')
  data_file  yes

  require 'erb'

  require 'flott'
  include Flott

  require_maybe 'kashmir'
  require_maybe 'eruby'
  require_maybe "amrita2" and include Amrita2
  require_maybe "tenjin"

  LENGTH = 500

  def setup
    @output = String.new
    @target = %'AAAAA9.865881AAAAA\n' * LENGTH
  end

  def common_output_reset
    @output != @target and
      raise "output incorrect: #{@output.inspect} != #{@target.inspect}"
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

  alias after_flott common_output_reset

  def setup_flott_escaped
    @env    = Environment.new(@output)
    @flott  = Parser.new( %'AAAAA[=3.141 ** 2]AAAAA\n' * LENGTH).compile
  end

  def benchmark_flott_escaped
    @flott.evaluate(@env)
  end

  alias after_flott_escaped common_output_reset

  def setup_erb
    @erb    = ERB.new(    %'AAAAA<%=3.141 ** 2%>AAAAA\n' * LENGTH, 0, '-')
  end

  def benchmark_erb
    @output = @erb.result
  end

  alias after_erb common_output_reset

  if defined? Kashmir
    def setup_kashmir
      @kashmir = Kashmir.new(%'AAAAA^(3.141 ** 2)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir
      @output = @kashmir.expand(Object.new)
    end

    alias after_kashmir common_output_reset

    def setup_kashmir_escaped
      @kashmir = Kashmir.for_XML(%'AAAAA^(3.141 ** 2)AAAAA\n' * LENGTH)
    end

    def benchmark_kashmir_escaped
      @output = @kashmir.expand(Object.new)
    end

    alias after_kashmir_escaped common_output_reset
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

    def after_eruby
      common_output_reset
      $stdout.rewind
    end
  end

  if defined? Amrita2
    def setup_amrita
      @amrita = Template.new(%'AAAAA<span am:src="test"></span>AAAAA\n' * LENGTH)
    end

    def benchmark_amrita
      @output = @amrita.render_with(:test => 3.141 ** 2).dup
    end

    alias after_amrita common_output_reset
  end

  if defined? Tenjin
    require 'tempfile'

    def setup_tenjin
      template = %'AAAAA\#{3.141 ** 2}AAAAA\n' * LENGTH
      tempfile = Tempfile.new 'temp'
      tempfile.write template
      tempfile.fsync
      @template_name = tempfile.path
      @tenjin  = Tenjin::Engine.new
    end

    def benchmark_tenjin
      @output = @tenjin.render(@template_name)
    end

    alias after_tenjin common_output_reset

    def setup_tenjin_escaped
      template = %'AAAAA${3.141 ** 2}AAAAA\n' * LENGTH
      tempfile = Tempfile.new 'temp'
      tempfile.write template
      tempfile.fsync
      @template_name = tempfile.path
      @tenjin  = Tenjin::Engine.new
    end

    def benchmark_tenjin_escaped
      @output = @tenjin.render(@template_name)
    end

    alias after_tenjin_escaped common_output_reset
  end
end
