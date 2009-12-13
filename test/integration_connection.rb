
#
# testing ruote-couch
#
# Sun Dec 13 20:22:43 JST 2009
#

require 'yajl'
require 'patron'

require 'ruote/couch/storage'


def new_storage (opts)

  Ruote::Couch::CouchStorage.new('127.0.0.1', 5984, 'ruote_couch_test')
end

