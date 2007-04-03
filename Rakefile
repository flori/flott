require 'rake/gempackagetask'
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
  ruby '-I lib tests/runner.rb'
end

desc "Testing library with line coverage"
task :coverage do
  sh 'rcov -I lib tests/runner.rb'
end

desc "Benchmarking library"
task :benchmark do
  cd 'benchmarks' do
    ruby '-I ../lib runner.rb'
  end
end

task :doc do
  ruby 'make_doc.rb'
end

desc "Removing generated files"
task :clean do
  rm_rf 'doc'
  rm_rf 'coverage'
end


spec = Gem::Specification.new do |s|
  #### Basic information.

  s.name = 'flott'
  s.version = PKG_VERSION
  s.summary = "Ruby as a templating language"
  s.description = ""

  #### Dependencies and requirements.

  #s.add_dependency('log4r', '> 1.0.4')
  #s.requirements << ""

  s.files = PKG_FILES

  #### C code extensions.

  #s.extensions << "ext/extconf.rb"

  #### Load-time details: library and application (you will need one or both).

  s.require_path = 'lib'                         # Use these for libraries.
  s.autorequire = 'flott'

  #s.bindir = "bin"                               # Use these for applications.
  #s.executables = ["bla.rb"]
  #s.default_executable = "bla.rb"

  #### Documentation and testing.

  s.has_rdoc = true
  #s.extra_rdoc_files = rd.rdoc_files.reject { |fn| fn =~ /\.rb$/ }.to_a
  #s.rdoc_options <<
  #  '--title' <<  'Rake -- Ruby Make' <<
  #  '--main' << 'README' <<
  #  '--line-numbers'
  s.test_files << 'tests/runner.rb'

  #### Author and project details.

  s.author = "Florian Frank"
  s.email = "flori@ping.de"
  s.homepage = "http://flott.rubyforge.org"
  s.rubyforge_project = "flott"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
  pkg.package_files += PKG_FILES
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
  # vim: set et sw=2 ts=2:
