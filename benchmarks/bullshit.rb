module Bullshit
  class BullshitException < StandardError; end

  class Clock
    TIMES = [ :total, :utime, :stime, :cutime, :cstime ]

    def initialize(u = 0.0, s = 0.0, cu = 0.0, cs = 0.0, real = 0.0)
      @utime, @stime, @cutime, @cstime, @real = u, s, cu, cs, real
      @total = @utime + @stime + @cutime + @cstime
    end

    def self.stop
      start = Process.times.to_a << Time.now
      yield
      stop = Process.times.to_a << Time.now
      new(*stop.zip(start).map { |x, y| x - y })
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
      "%10.6f %10.6f %10.6f %10.6f %10.6f %10.6f\n" %
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

  module CaseExtension
    def cases
      @cases ||= []
    end

    def inherited(klass)
      cases << klass
    end

    def each(&block)
      cases.each(&block)
    end

    def run_all
      each do |bc_klass|
        bc = bc_klass.new
        STDERR.puts "Running Bullshit::Case '#{bc_klass}'."
        Bullshit.process(bc) do |reporter|
          begin
            bc.setup
            bc.run(reporter)
          rescue => e
            puts "Caught #{e.class}: #{([e] + e.backtrace) * "\n"}"
          ensure
            bc.teardown
            bc = bc_klass.new
          end
        end
      end
    end
  end

  class Case
    extend CaseExtension

    def benchmarks
      methods.grep(/^benchmark_/).sort_by { rand }
    end

    def shorten(name)
      name.sub(/^benchmark_/, '')
    end

    def names
      benchmarks.map { |x| shorten(x) }
    end

    def longest_name
      names.max { |a, b| a.size <=> b.size }.size
    end

    def setup
    end

    def run
    end
    
    def teardown
    end
  end

  class TimeCase < Case
    def initialize
      super
      @time = 10
    end

    attr_accessor :time

    def run(reporter)
      benchmarks.each do |b|
        start = Time.now
        count = 0
        until Time.now - @time > start
          __send__(b)
          count += 1
        end
        #reporter.report(shorten(b), foo)
      end
    end
  end

  class RepeatCase < Case
    def initialize
      super
      @repeat = 1
    end

    attr_accessor :repeat

    def format(time, repeat)
    end

    def run(reporter)
      benchmarks.each do |b|
        start = Time.now
        repeat.times { __send__(b) }
        duration = Time.now - start
        #reporter.report(shorten(b), foo)
      end
    end
  end
end
