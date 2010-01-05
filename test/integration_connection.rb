
#
# testing ruote-couch
#
# Sun Dec 13 20:22:43 JST 2009
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

require 'patron' rescue nil

require 'ruote/couch/storage'


def new_storage (opts)

  opts ||= {}

  Ruote::Couch::CouchStorage.new(
    '127.0.0.1', 5984, opts.merge!('prefix' => 'test'))
end

