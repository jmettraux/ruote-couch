# encoding: utf-8

Gem::Specification.new do |s|

  s.name = 'ruote-couch'

  s.version = File.read(
    File.expand_path('../lib/ruote/couch/version.rb', __FILE__)
  ).match(/ VERSION *= *['"]([^'"]+)/)[1]

  s.platform = Gem::Platform::RUBY
  s.authors = [ 'John Mettraux', 'Marcello Barnaba' ]
  s.email = [ 'jmettraux@gmail.com', 'vjt@openssl.it' ]
  s.homepage = 'http://github.com/jmettraux/ruote-couch'
  s.summary = "CouchDB storage for ruote #{s.version} and up"
  s.description = %{
CouchDB storage for ruote #{s.version} and up (ruby workflow engine)
  }.strip

  s.files = `git ls-files`.split("\n")

  s.add_runtime_dependency 'ruote', "~> #{s.version.to_s.split('.')[0, 3].join('.')}"
  s.add_dependency 'rufus-jig', '>= 1.0.0'

  s.add_development_dependency 'rake'

  s.require_path = 'lib'
end

