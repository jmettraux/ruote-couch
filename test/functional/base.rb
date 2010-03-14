
$:.unshift(File.join(File.dirname(__FILE__), '..', '..', '..', 'ruote', 'lib'))
$:.unshift(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

require 'test/unit'

require 'rubygems'
require 'yajl'

require 'patron' unless ARGV.include?('--net')
  # TODO : provide for em-http-request

require 'ruote'
require 'ruote/couch'

