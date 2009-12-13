
#
# testing ruote-couch
#
# Fri Dec 11 22:06:25 JST 2009
#

require File.join(File.dirname(__FILE__), '..', 'test_helper.rb')

require 'ruote/couch/storage'
require 'ruote/engine'
require 'ruote/worker'


class FtInitialTest < Test::Unit::TestCase

  def test_echo

    #require 'ruote/storage/hash_storage'
    #storage = Ruote::HashStorage.new
    storage = Ruote::Couch::CouchStorage.new(
      '127.0.0.1', 5984, 'ruote_couch_test')

    engine = Ruote::Engine.new(Ruote::Worker.new(storage))

    engine.context[:noisy] = true

    pdef = Ruote.process_definition :name => 'test' do
      echo '* SEEN *'
    end

    wfid = engine.launch(pdef)

    engine.wait_for(wfid)
  end
end

