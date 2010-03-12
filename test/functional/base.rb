
$:.unshift(File.join(File.dirname(__FILE__), '..', '..', '..', 'ruote', 'lib'))
$:.unshift(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

require 'test/unit'

require 'yajl'
require 'patron'

require 'ruote'
require 'ruote/couch'

