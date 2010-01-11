
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

  gem.add_dependency 'ruote', ">= #{Ruote::Couch::VERSION}"
  #gem.add_dependency 'yajl-ruby'
  #gem.add_dependency 'json'
  gem.add_dependency 'rufus-jig', '>= 0.1.11'
  gem.add_development_dependency 'yard', '>= 0'

  # gemspec spec : http://www.rubygems.org/read/chapter/20
end
Jeweler::GemcutterTasks.new


#
# DOC

begin

  require 'yard'

  YARD::Rake::YardocTask.new do |doc|
    doc.options = [
      '-o', 'html/ruote-couch', '--title',
      "ruote-couch #{Ruote::Couch::VERSION}"
    ]
  end

rescue LoadError

  task :yard do
    abort "YARD is not available : sudo gem install yard"
  end
end


#
# TO THE WEB

task :upload_website => [ :clean, :yard ] do

  account = 'jmettraux@rubyforge.org'
  webdir = '/var/www/gforge-projects/ruote'

  sh "rsync -azv -e ssh html/ruote-couch #{account}:#{webdir}/"
end

