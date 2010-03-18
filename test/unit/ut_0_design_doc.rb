
#
# testing ruote-couch
#
# Thu Mar 18 09:15:11 JST 2010
#

#require File.join(File.dirname(__FILE__), 'base')
$:.unshift(File.join(File.dirname(__FILE__), '..', '..', '..', 'ruote', 'lib'))
$:.unshift(File.join(File.dirname(__FILE__), '..', '..', 'lib'))
require 'test/unit'
require 'ruote/couch'


class UtDesignDocTest < Test::Unit::TestCase

  #def setup
  #end
  #def teardown
  #end

  def test_design_docs

    assert_equal Hash, Ruote::Couch::WfidIndexedDatabase.design_doc.class
    assert_equal Hash, Ruote::Couch::WorkitemDatabase.design_doc.class
  end
end

