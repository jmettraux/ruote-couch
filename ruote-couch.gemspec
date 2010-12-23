# encoding: utf-8

Gem::Specification.new do |s|

  s.name = 'ruote-couch'
  s.version = File.read('lib/ruote/couch/version.rb').match(/VERSION = '([^']+)'/)[1]
  s.platform = Gem::Platform::RUBY
  s.authors = [ 'John Mettraux' ]
  s.email = [ 'jmettraux@gmail.com' ]
  s.homepage = 'http://github.com/jmettraux/ruote-couch'
  s.rubyforge_project = 'ruote'
  s.summary = 'CouchDB storage for ruote 2.1'
  s.description = %{
CouchDB storage for ruote 2.1 (ruby workflow engine)
  }.strip

  #s.files = `git ls-files`.split("\n")
  s.files = Dir[
    'Rakefile',
    'lib/**/*.rb', 'spec/**/*.rb', 'test/**/*.rb',
    '*.gemspec', '*.txt', '*.rdoc', '*.md'
  ]

  s.add_dependency 'ruote', ">= #{s.version}"
  s.add_dependency 'rufus-jig', '>= 1.0.0'

  s.add_development_dependency 'rake'

  s.require_path = 'lib'
end

