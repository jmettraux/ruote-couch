
require 'rubygems'
require 'rake'

require 'lib/ruote/couch/version.rb'

#
# CLEAN

require 'rake/clean'
CLEAN.include('pkg', 'tmp', 'html')
task :default => [ :clean ]


#
# GEM

require 'jeweler'

Jeweler::Tasks.new do |gem|

  gem.version = Ruote::Couch::VERSION
  gem.name = 'ruote-couch'
  gem.summary = 'CouchDB storage for ruote 2.1'
  gem.description = %{
CouchDB storage for ruote 2.1 (ruby workflow engine)
  }.strip
  gem.email = 'jmettraux@gmail.com'
  gem.homepage = 'http://github.com/jmettraux/ruote-couch'
  gem.authors = [ 'John Mettraux' ]
  gem.rubyforge_project = 'ruote'

  gem.test_file = 'test/test.rb'

  #gem.add_dependency 'ruote', ">= #{Ruote::Couch::VERSION}"
  gem.add_dependency 'ruote', ">= 2.1.11"
  gem.add_dependency 'rufus-jig', '>= 0.1.23'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'jeweler'

  # gemspec spec : http://www.rubygems.org/read/chapter/20
end
Jeweler::GemcutterTasks.new

#
# MISC

task :delete_all_test_databases do

  require 'json'
  require 'rufus/jig'
  couch = Rufus::Jig::Couch.new('127.0.0.1', 5984)
  %w[
    configurations errors expressions msgs schedules variables workitems
  ].each do |type|
    couch.delete("/test_ruote_#{type}")
  end
end


#
# DOC

#
# make sure to have rdoc 2.5.x to run that
#
require 'rake/rdoctask'
Rake::RDocTask.new do |rd|

  rd.main = 'README.rdoc'
  rd.rdoc_dir = 'rdoc/ruote-couch_rdoc'

  rd.rdoc_files.include(
    'README.rdoc', 'CHANGELOG.txt', 'CREDITS.txt', 'lib/**/*.rb')

  rd.title = "ruote-couch #{Ruote::Couch::VERSION}"
end


#
# TO THE WEB

task :upload_rdoc => [ :clean, :rdoc ] do

  account = 'jmettraux@rubyforge.org'
  webdir = '/var/www/gforge-projects/ruote'

  sh "rsync -azv -e ssh rdoc/ruote-couch_rdoc #{account}:#{webdir}/"
end

