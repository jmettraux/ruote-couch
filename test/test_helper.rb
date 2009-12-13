
#
# testing ruote-couch
#
# Thu Dec 10 11:09:17 JST 2009
#

require File.join(File.dirname(__FILE__), 'path_helper')

require 'test/unit'
require 'rubygems'

require 'patron' # gem install patron
#require 'net/http'

require 'yajl' # gem install yajl-ruby

$:.unshift('~/w/rufus/rufus-jig/lib')
  # TODO : remove me once jig is stable vis-a-vis couch

