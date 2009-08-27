#!/usr/bin/env ruby

$outdir = 'doc/'
puts "Creating documentation in '#$outdir'."
system "rdoc -o #$outdir lib/flott.rb lib/flott/*.rb"
