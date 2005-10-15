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

  begin
    require 'eruby'
  rescue LoadError
  end

  repeat_duration 10
  
  def setup
    @output = String.new 
    @flott  = Parser.new( %'AAAAA[!Time.now]AAAAA' * 10).compile
    @erb    = ERB.new(    %'AAAAA<%=Time.now%>AAAAA' * 10, 0, '%<>')
    @env    = Environment.new(@output)
    if defined? Kashmir
      @kashmir = Kashmir.new(%'AAAAA^(Time.now)AAAAA' * 10)
    end
    if defined? ERuby
      require 'stringio'
      ec = ERuby::Compiler.new
      @eruby = ec.compile_string(%'AAAAA<%=Time.now%>AAAAA' * 10)
      @output = ''
      $stdout = StringIO.new(@output)
    end
  end

  def benchmark_flott
    @flott.evaluate(@env)
  end

  def benchmark_erb
    @erb.result
  end

if defined? Kashmir
  def benchmark_kashmir
    @kashmir.expand(Object.new)
  end
end

if defined? ERuby
  def benchmark_eruby
    eval(@eruby)
    #STDERR.puts @output.inspect
  end
end
end

=begin
=end
