# Rakefile for File::Tail  -*- ruby -*-

require 'rake/gempackagetask'
require 'rbconfig'

include Config

PKG_NAME = 'flott'
PKG_VERSION = File.read('VERSION').chomp
PKG_FILES = Dir.glob("**/*").delete_if { |item|
    item.include?("CVS") or item.include?("pkg")
}

desc "Installing library"
task :install  do
    dest = CONFIG["sitelibdir"]
    install('lib/flott.rb', dest)
    dest = File.join(dest, 'flott')
    mkdir_p dest
    install('lib/flott/cache.rb', dest)
end

desc "Testing library"
task :test do
    ruby 'tests/runner.rb'
end

spec = Gem::Specification.new do |s|

    #### Basic information.

    s.name = 'flott'
    s.version = PKG_VERSION
    s.summary = "Implementation of lazy lists for Ruby"
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
    # vim: set et sw=4 ts=4:
