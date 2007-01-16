#!/usr/bin/env ruby

require 'test/unit/ui/console/testrunner'
require 'test/unit/testsuite'
$:.unshift File.expand_path(File.dirname(__FILE__))
$:.unshift 'lib'
$:.unshift '../lib'
begin
  require 'coverage'
rescue LoadError
end
require 'test_flott'
require 'test_flott_file'
require 'test_cache'

class TS_AllTests
  def self.suite
    suite = Test::Unit::TestSuite.new 'All Tests'
    suite << TC_Flott.suite
    suite << TC_FlottFile.suite
    suite << TC_Cache.suite
  end
end
Test::Unit::UI::Console::TestRunner.run(TS_AllTests)
  # vim: set et sw=2 ts=2:
