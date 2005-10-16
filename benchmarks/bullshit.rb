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

    def self.output_times
      %w[real total utime stime cutime cstime]
    end

    def self.header(bullshit_case)
      result = ''
      result << ' ' * (bullshit_case.longest_name + 1)
      result << ('%11s' * 6) % output_times << "\n"
    end

    def body(bullshit_case)
      result = ''
      result << ('%11.6f' * 6) % self.class.output_times.map { |t| __send__(t) }
      result << "\n"
      result << ' ' * (bullshit_case.longest_name + 1)
      result << '%11u %11.6f' % [ repeat, repeat / total ]
    end

    def self.footer(bullshit_case)
      result = ''
      result << ' ' * (bullshit_case.longest_name + 1)
      result << '%11s %11s' % %w[calls calls/sec]
    end
  end

  class Case
    class Script
    end

    module CaseExtension
      def inherited(klass)
        Case.cases << klass
      end

      attr_accessor :rehearsal
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

      def run_method(bullshit_case, bmethod)
        bullshit_case.run bmethod
      rescue => e
        STDERR.puts "Caught #{e.class}: #{([e] + e.backtrace) * "\n"}"
      ensure
        bullshit_case.teardown
      end

      def run_bullshit_case(bc_klass, bullshit_case)
        STDERR.puts bc_klass.message
        STDERR.puts Clock.header(bullshit_case)
        bullshit_case.bmethods.each do |bmethod|
          run_method(bullshit_case, bmethod)
        end
        STDERR.puts Clock.footer(bullshit_case)
        STDERR.puts '-' * 80
      end
      
      def run_all
        each do |bc_klass|
          bullshit_case = bc_klass.new
          if bc_klass.rehearsal
            STDERR.puts "First run for rehearsal."
            run_bullshit_case(bc_klass, bullshit_case)
          end
          run_bullshit_case(bc_klass, bullshit_case)
          STDERR.puts '=' * 80
        end
      end
    end

    def initialize
      setup
    end

    class CaseMethod < Struct.new(:name, :case)
      def short_name
        @short_name ||= name.sub(/^benchmark_/, '')
      end

      def setup_name
        'setup_' + name
      end
      
      def reset_name
        'reset_' + name
      end

      def teardown_name
        'teardown_' + name
      end

      def prefix_string
        "% -#{self.case.longest_name}s: " % short_name
      end
    end

    def bmethods
      @bmethods ||= methods.grep(/^benchmark_/).sort_by { rand }.map do |n|
        CaseMethod.new(n, self)
      end
    end

    def longest_name
      bmethods.empty? and return 0
      bmethods.max do |a, b|
        a.short_name.size <=> b.short_name.size
      end.short_name.size
    end

    def setup
    end

    def pre_run bmethod
      __send__(bmethod.setup_name) if respond_to? bmethod.setup_name
      STDERR.print bmethod.prefix_string
    end

    def run bmethod
      pre_run bmethod
      post_run bmethod
    end

    def reset
    end
    
    def reset_run(bmethod)
      if respond_to? bmethod.reset_name
        __send__(bmethod.reset_name)
      else
        reset
      end
    end

    def post_run(bmethod)
      __send__(bmethod.teardown_name) if respond_to? bmethod.teardown_name
    end
    
    def teardown
    end
  end

  class TimeCase < Case
    class << self
      def repeat_duration(seconds)
        @duration = seconds
      end

      attr_reader :duration

      def message
        "Running '#{self}' for a duration of #{duration} secs:"
      end
    end
    
    def run(bmethod)
      pre_run bmethod
      clock = Clock.repeat(self.class.duration) do
        __send__(bmethod.name)
        reset_run bmethod
      end
      STDERR.puts clock.body(self)
      post_run bmethod
      #reporter.report(shorten(bmethod), foo)
    end
  end

  class RepeatCase < Case
    class << self
      def repeat_iterations(iterations)
        @iterations = iterations
      end

      attr_reader :iterations

      def message
        "Running '#{self}' for #{iterations} iterations:"
      end
    end

    def run(bmethod)
      pre_run bmethod
      clock = Clock.stop(self.class.iterations) do
        __send__(bmethod.name)
        reset_run bmethod
      end
      STDERR.puts clock.body(self)
      post_run bmethod
    end
  end
end
