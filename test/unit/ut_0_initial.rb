
#
# testing ruote-couch
#
# Thu Dec 10 11:07:56 JST 2009
#

require File.join(File.dirname(__FILE__), '..', 'test_helper.rb')

require 'ruote/couch/storage'


class UtInitialTest < Test::Unit::TestCase

  def test_connect

    storage = Ruote::Couch::CouchStorage.new(
      'localhost', 5984, 'ruote_couch_test')
  end
end

