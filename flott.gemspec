# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "flott"
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Florian Frank"]
  s.date = "2012-05-11"
  s.description = "Ruby as a templating language"
  s.email = "flori@ping.de"
  s.extra_rdoc_files = ["README.rdoc", "lib/flott.rb", "lib/flott/version.rb", "lib/flott/cache.rb"]
  s.files = [".gitignore", ".travis.yml", "Gemfile", "README.rdoc", "Rakefile", "VERSION", "benchmarks/data/.keep", "benchmarks/flott_benchmark.rb", "benchmarks/runner.rb", "doc-main.txt", "flott.gemspec", "install.rb", "lib/flott.rb", "lib/flott/cache.rb", "lib/flott/version.rb", "make_doc.rb", "tests/templates/header", "tests/templates/subdir/deeptemplate", "tests/templates/subdir/included", "tests/templates/subdir/subdir2/deepincluded2", "tests/templates/subdir/subdir2/included2", "tests/templates/subdir/subdir3/included3", "tests/templates/template", "tests/templates/template2", "tests/templates/toplevel", "tests/templates/toplevel2", "tests/test_cache.rb", "tests/test_flott.rb", "tests/test_flott_file.rb", "tests/test_helper.rb"]
  s.homepage = "http://github.com/flori/flott"
  s.rdoc_options = ["--title", "Flott - Ruby as a templating language", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"
  s.summary = "Ruby as a templating language"
  s.test_files = ["tests/test_flott_file.rb", "tests/test_flott.rb", "tests/test_cache.rb", "tests/test_helper.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<gem_hadar>, ["~> 0.1.8"])
      s.add_runtime_dependency(%q<bullshit>, ["~> 0.1.3"])
      s.add_runtime_dependency(%q<rake>, ["= 0.9.2.2"])
      s.add_runtime_dependency(%q<tins>, ["~> 0.4.2"])
    else
      s.add_dependency(%q<gem_hadar>, ["~> 0.1.8"])
      s.add_dependency(%q<bullshit>, ["~> 0.1.3"])
      s.add_dependency(%q<rake>, ["= 0.9.2.2"])
      s.add_dependency(%q<tins>, ["~> 0.4.2"])
    end
  else
    s.add_dependency(%q<gem_hadar>, ["~> 0.1.8"])
    s.add_dependency(%q<bullshit>, ["~> 0.1.3"])
    s.add_dependency(%q<rake>, ["= 0.9.2.2"])
    s.add_dependency(%q<tins>, ["~> 0.4.2"])
  end
end
