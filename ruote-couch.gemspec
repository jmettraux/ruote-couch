
Gem::Specification.new do |s|

  s.name = 'ruote-couch'
  s.version = '2.1.0'
  s.authors = [ 'John Mettraux' ]
  s.email = 'jmettraux@gmail.com'
  s.homepage = 'http://ruote.rubyforge.org'
  s.platform = Gem::Platform::RUBY
  s.summary = 'CouchDB storage for ruote 2.1'
  s.description = %{
CouchDB storage for ruote 2.1 (ruby workflow engine)
  }.strip

  s.require_path = 'lib'
  s.rubyforge_project = 'openwferu'
  #s.autorequire = 'ruote'
  s.test_file = 'test/test.rb'
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README.rdoc' ]

  [
    #'ruote',
    'rufus-jig'
  ].each { |d|
    s.requirements << d
    s.add_dependency(d)
  }

  #files = FileList[ '{bin,docs,lib,test,examples}/**/*' ]
  files = FileList[ '{lib}/**/*' ]
  files.exclude 'ruote_dm_rdoc'
  #files.exclude 'extras'
  s.files = files.to_a
end

