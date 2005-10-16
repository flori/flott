#!/usr/bin/env ruby

$outdir = 'doc/'
puts "Creating documentation in '#$outdir'."
system "rdoc --all -d -o #$outdir lib/flott.rb"
    # vim: set et sw=4 ts=4:
