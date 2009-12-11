
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

    storage = Ruote::Couch::CouchStorage.new(
      'localhost', 5984, 'ruote_couch_test')

    engine = Ruote::Engine.new(Ruote::Worker.new(storage))

    pdef = Ruote.process_definition :name => 'test' do
      echo 'a'
    end

    wfid = engine.launch(pdef)

    #engine.wait_for(wfid)
    sleep 2
  end
end

