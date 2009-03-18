Gem::Specification.new do |s|
  s.name = %q{gitjour}
  s.version = "6.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Chad Fowler", "Evan Phoenix", "Rich Kilmer", "Phil Hagelberg"]
  s.date = %q{2009-03-17}
  s.default_executable = %q{gitjour}
  s.email = ["chad@chadfowler.com", "evan@fallingsnow.net", "rich@example.com", "technomancy@gmail.com"]
  s.executables = ["gitjour"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/gitjour", "lib/gitjour.rb", "lib/gitjour/browser.rb", "test/test_gitjour.rb", "test/test_helper.rb"]
  s.has_rdoc = true
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{gitjour}
  s.rubygems_version = %q{1.3.1}
  s.summary = nil
  s.test_files = ["test/test_gitjour.rb", "test/test_helper.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<dnssd>, ["~> 0.7.1"])
      s.add_development_dependency(%q<hoe>, [">= 1.9.0"])
    else
      s.add_dependency(%q<dnssd>, ["~> 0.7.1"])
      s.add_dependency(%q<hoe>, [">= 1.9.0"])
    end
  else
    s.add_dependency(%q<dnssd>, ["~> 0.7.1"])
    s.add_dependency(%q<hoe>, [">= 1.9.0"])
  end
end

