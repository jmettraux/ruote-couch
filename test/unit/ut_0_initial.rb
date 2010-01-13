
#
# testing ruote-couch
#
# Thu Dec 10 11:07:56 JST 2009
#

require File.join(File.dirname(__FILE__), '..', 'test_helper.rb')
require File.join(File.dirname(__FILE__), '..', 'integration_connection.rb')


class UtInitialTest < Test::Unit::TestCase

  def test_connect

    storage = new_storage(nil)

    v = storage.get_many('configurations')

    #p v

    assert_equal 1, v.size
  end
end

