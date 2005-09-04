#!/usr/bin/env ruby

require 'test/unit/ui/console/testrunner'
require 'test/unit/testsuite'
$:.unshift File.expand_path(File.dirname($0))
$:.unshift 'lib'
$:.unshift '../lib'
begin
  require 'coverage'
rescue LoadError
end
require 'test_flott'

class TS_AllTests
  def self.suite
    suite = Test::Unit::TestSuite.new
    suite << TC_Flott.suite
  end
end
Test::Unit::UI::Console::TestRunner.run(TS_AllTests)
  # vim: set et sw=2 ts=2:
