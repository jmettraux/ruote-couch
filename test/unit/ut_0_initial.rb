
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

    v = storage.couch.get('_design/ruote/_view/by_type')

    assert_equal 1, v['total_rows']

    #p v['rows']
  end
end

