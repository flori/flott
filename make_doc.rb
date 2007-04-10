#!/usr/bin/env ruby

$outdir = 'doc/'
puts "Creating documentation in '#$outdir'."
system "rdoc -d -o #$outdir lib/flott.rb lib/flott/*.rb"
    # vim: set et sw=4 ts=4:
