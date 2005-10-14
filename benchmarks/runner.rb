#!/usr/bin/env ruby

require 'bullshit'
include Bullshit

for b in Dir['[0-9]*_benchmark_*.rb']
  require b
end
Case.run_all
