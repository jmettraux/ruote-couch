# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ruote-couch}
  s.version = "2.1.10"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mettraux"]
  s.date = %q{2010-06-15}
  s.description = %q{CouchDB storage for ruote 2.1 (ruby workflow engine)}
  s.email = %q{jmettraux@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE.txt",
     "README.rdoc"
  ]
  s.files = [
    "CHANGELOG.txt",
     "LICENSE.txt",
     "README.rdoc",
     "Rakefile",
     "TODO.txt",
     "lib/ruote-couch.rb",
     "lib/ruote/couch.rb",
     "lib/ruote/couch/database.rb",
     "lib/ruote/couch/storage.rb",
     "lib/ruote/couch/version.rb",
     "ruote-couch.gemspec",
     "test/functional/base.rb",
     "test/functional/ft_0_long_polling.rb",
     "test/functional/test.rb",
     "test/functional_connection.rb",
     "test/test.rb",
     "test/unit/test.rb",
     "test/unit/ut_0_design_doc.rb"
  ]
  s.homepage = %q{http://github.com/jmettraux/ruote-couch}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ruote}
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{CouchDB storage for ruote 2.1}
  s.test_files = [
    "test/test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ruote>, [">= 2.1.10"])
      s.add_runtime_dependency(%q<rufus-jig>, [">= 0.1.18"])
      s.add_development_dependency(%q<yard>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, [">= 0"])
    else
      s.add_dependency(%q<ruote>, [">= 2.1.10"])
      s.add_dependency(%q<rufus-jig>, [">= 0.1.18"])
      s.add_dependency(%q<yard>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
    end
  else
    s.add_dependency(%q<ruote>, [">= 2.1.10"])
    s.add_dependency(%q<rufus-jig>, [">= 0.1.18"])
    s.add_dependency(%q<yard>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
  end
end

