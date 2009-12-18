
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
      '127.0.0.1', 5984, :prefix => 'test')

    v = storage.get_many('configurations')

    #p v

    assert_equal 1, v.size
  end
end

