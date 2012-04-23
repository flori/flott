# vim: set filetype=ruby et sw=2 ts=2:

require 'gem_hadar'

GemHadar do
  name        'flott'
  author      'Florian Frank'
  email       'flori@ping.de'
  homepage    "http://github.com/flori/#{name}"
  summary     'Ruby as a templating language'
  description summary
  test_dir    'tests'
  ignore      '.*.sw[pon]', 'pkg', 'Gemfile.lock', '.rvmrc', '.AppleDouble'
  readme      'README.rdoc'
  clobber     Dir['benchmarks/data/*.{dat,log}'], 'coverage'

  dependency  'bullshit', '~>0.1.3'
  dependency  'rake',     '0.9.2.2'
  dependency  'tins',     '~>0.4.2'
end

desc "Benchmarking library"
task :benchmark do
  ruby '-Ilib benchmarks/runner.rb'
end
