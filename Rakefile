begin
  require 'rake/gempackagetask'
  require 'rake/extensiontask'
rescue LoadError
end

require 'rake/clean'
CLEAN.include 'doc', 'coverage'
CLOBBER.include Dir['benchmarks/data/*.{dat,log}']

require 'rbconfig'
include Config

PKG_NAME = 'flott'
PKG_VERSION = File.read('VERSION').chomp
PKG_FILES = FileList["**/*"].exclude(/.svn|CVS|^pkg|^coverage/)

desc "Installing library"
task :install  do
  ruby 'install.rb'
end

desc "Testing library"
task :test do
  sh 'testrb -Ilib tests/test_*.rb'
end

desc "Testing library with line coverage"
task :coverage do
    sh 'rcov -xtests -I lib tests/test_*.rb'
end

desc "Benchmarking library"
task :benchmark do
  ruby '-Ilib benchmarks/runner.rb'
end

task :doc do
  ruby 'make_doc.rb'
end

if defined?(Gem) and defined?(Rake::GemPackageTask)
  spec = Gem::Specification.new do |s|
    s.name = 'flott'
    s.version = PKG_VERSION
    s.summary = "Ruby as a templating language"
    s.description = ""

    s.files = PKG_FILES

    s.require_path = 'lib'                         # Use these for libraries.

    s.has_rdoc = true
    s.extra_rdoc_files << 'doc-main.txt'
    s.rdoc_options <<
      '--title' <<  'Flott­- Floris Tolle Templates' <<
      '--main' << 'doc-main.txt'
    s.test_files.concat Dir['tests/test_*.rb']

    s.author = "Florian Frank"
    s.email = "flori@ping.de"
    s.homepage = "http://flott.rubyforge.org"
    s.rubyforge_project = "flott"
  end

  Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
    pkg.package_files += PKG_FILES
  end
end

desc m = "Writing version information for #{PKG_VERSION}"
task :version do
  puts m
  File.open(File.join('lib', 'flott', 'version.rb'), 'w') do |v|
    v.puts <<EOT
module Flott
  # Flott version
  VERSION         = '#{PKG_VERSION}'
  VERSION_ARRAY   = VERSION.split(/\\./).map { |x| x.to_i } # :nodoc:
  VERSION_MAJOR   = VERSION_ARRAY[0] # :nodoc:
  VERSION_MINOR   = VERSION_ARRAY[1] # :nodoc:
  VERSION_BUILD   = VERSION_ARRAY[2] # :nodoc:
end
EOT
  end
end

task :release => [ :clean, :version, :package ]
