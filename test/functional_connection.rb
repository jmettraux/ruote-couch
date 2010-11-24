
#
# testing ruote-couch
#
# Sun Dec 13 20:22:43 JST 2009
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

unless $http_lib_loaded
  begin
    if ARGV.include?('--patron')
      require 'patron'
      puts ' : using patron'
    elsif ARGV.include?('--netp')
      require 'net/http/persistent'
      puts ' : using net-http-persistent'
    else
      puts ' : using net/http'
    end
  rescue LoadError => le
    # then use 'net/http'
    puts ' : falling back to net/http'
  end
  $http_lib_loaded = true
end

require 'ruote/couch/storage'

def _couch_url

  File.read('couch_url.txt').strip rescue 'http://127.0.0.1:5984'
end


unless $_RUOTE_COUCH_CLEANED

  couch = Rufus::Jig::Couch.new(_couch_url)
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

  #Ruote::Couch::CouchStorage.new(
  #  _couch_url,
  #  opts.merge!('couch_prefix' => 'test', :basic_auth => %w[ admin admin ]))
  Ruote::Couch::CouchStorage.new(
    _couch_url,
    opts.merge!('couch_prefix' => 'test'))
end

