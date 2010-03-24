
#
# testing ruote-couch
#
# Sun Dec 13 20:22:43 JST 2009
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

begin
  require 'patron' unless ARGV.include?('--net')
rescue LoadError
  # then use 'net/http'
end

require 'ruote/couch/storage'


unless $_RUOTE_COUCH_CLEANED

  couch = Rufus::Jig::Couch.new('127.0.0.1', 5984)
  %w[
    configurations errors expressions msgs schedules variables workitems
  ].each do |type|
    couch.delete("/test_ruote_#{type}")
  end
  puts "(purged all /test_ruote_xxx databases)"
  $_RUOTE_COUCH_CLEANED = true
end


def new_storage (opts)

  opts ||= {}

  Ruote::Couch::CouchStorage.new(
    '127.0.0.1',
    5984,
    opts.merge!('couch_prefix' => 'test', 'couch_timeout' => 1))
end

