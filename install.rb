#!/usr/bin/env ruby

require 'rbconfig'
require 'fileutils'
include FileUtils::Verbose
include Config

dest = CONFIG["sitelibdir"]
mkdir_p(dest)
file = 'lib/flott.rb'
install(file, dest)

dest = File.join(dest, 'flott')
mkdir_p dest
file = 'lib/flott/cache.rb'
install(file, dest)
