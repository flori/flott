#!/usr/bin/env ruby

require 'rbconfig'
require 'fileutils'

include Config

$file = 'lib/flott.rb'
$libdir = CONFIG["sitelibdir"]

$dest = $libdir
FileUtils::mkdir_p($dest)
$stderr.puts "Installing '#$file' into '#$dest'."
FileUtils.install($file, $dest)
    # vim: set et sw=4 ts=4:
