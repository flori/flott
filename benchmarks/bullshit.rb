require 'timeout'

module Bullshit
  class BullshitException < StandardError; end

  class Clock
    TIMES = [ :total, :utime, :stime, :cutime, :cstime ]

    def initialize(u = 0.0, s = 0.0, cu = 0.0, cs = 0.0, real = 0.0)
      @utime, @stime, @cutime, @cstime, @real = u, s, cu, cs, real
      @total = @utime + @stime + @cutime + @cstime
    end

    attr_accessor :repeat

    def self.stop(repeat)
      start = Process.times.to_a << Time.now
      repeat.times { yield }
      stop = Process.times.to_a << Time.now
      clock = new(*stop.zip(start).map { |x, y| x - y })
      clock.repeat = repeat
      clock
    end

    def self.repeat(time)
      repeat = 0
      start = Process.times.to_a << s = Time.now
      timeout(time) do
        loop do
          yield
          repeat += 1
        end
      end
    rescue Timeout::Error
      stop = Process.times.to_a << Time.now
      clock = new(*stop.zip(start).map { |x, y| x - y })
      clock.repeat = repeat
      clock
    end

    # utime: Amount of User CPU time, in seconds
    attr_reader :utime

    # stime: Amount of System CPU time, in seconds
    attr_reader :stime

    # cutime: Completed child processes' User CPU time, in seconds (always 0 on
    # Windows NT)
    attr_reader :cutime
    
    # cstime: Completed child processes' System CPU time, in seconds (always 0
    # on Windows NT)
    attr_reader :cstime

    # total time: sum of utime, stime, cutime, and cstime
    attr_reader :total

    # real: real time elapsed
    attr_reader :real

    def +(other)
      self.class.new(*TIMES.map { |t| __send__(t) + other.__send__(t) })
    end

    def -(other)
      self.class.new(*TIMES.map { |t| __send__(t) - other.__send__(t) })
    end

    def *(x)
      self.class.new(*TIMES.map { |t| __send__(t) * x })
    end

    def /(x)
      self.class.new(*TIMES.map { |t| __send__(t) / x })
    end

    def to_s
      "%10.6f %10.6f %10.6f %10.6f %10.6f %10.6f" %
        [ real, total, utime, stime, cutime, cstime ]
    end
  end

  class Reporter
    def initialize(benchmark_case)
      @benchmark_case = benchmark_case
    end

    def report(name)
      measure = 0.0
      printf "%#{@benchmark_case.longest_name}s:%s\n", name, measure
    end
  end
  
  def process(indent)
    reporter = Reporter.new(indent)
    yield reporter
  end

  class Case
    class Script
    end

    module CaseExtension
      def inherited(klass)
        Case.cases << klass
      end
    end

    class << self
      def inherited(klass)
        klass.extend CaseExtension
      end

      def cases
        @cases ||= []
      end

      def each(&block)
        cases.each(&block)
      end

      def run_method(bc, bmethod)
        bc.run(bmethod)
      rescue => e
        puts "Caught #{e.class}: #{([e] + e.backtrace) * "\n"}"
      ensure
        bc.teardown
      end

      def run_all
        each do |bc_klass|
          bc = bc_klass.new
          puts "Running Bullshit::Case '#{bc_klass}':"
          bc.bmethods.each do |bmethod|
            run_method(bc, bmethod)
          end
          puts
        end
      end
    end

    def initialize
      setup
    end

    class CaseMethod < Struct.new(:name)
      def short_name
        @short_name ||= name.sub(/^benchmark_/, '')
      end
    end

    def bmethods
      @bmethods ||= methods.grep(/^benchmark_/).sort_by { rand }.map do |n|
        CaseMethod.new(n)
      end
    end

    def longest_name
      bmethods.max { |a, b|
        a.short_name.size <=> b.short_name.size
      }.short_name.size
    end

    def setup
    end

    def run(*)
    end
    
    def teardown
    end
  end

  class TimeCase < Case
    def initialize
      @time = 10
      super
    end

    attr_accessor :time

    def run(b)
      clock = Clock.repeat(@time) { __send__(b.name) }
      printf "% -#{longest_name}s: %s %u\n", b.short_name, clock.to_s, clock.repeat
      #reporter.report(shorten(b), foo)
    end
  end

  class RepeatCase < Case
    def initialize
      @repeat = 1
      super
    end

    attr_accessor :repeat

    def run(b)
      clock = Clock.stop(repeat) { __send__(b.name) }
      printf "% -#{longest_name}s: %s %u\n", b.short_name, clock.to_s, clock.repeat
    end
  end
end
