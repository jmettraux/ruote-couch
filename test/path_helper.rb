
#
# testing ruote-couch
#
# Thu Dec 10 11:04:02 JST 2009
#

ruote_lib = File.expand_path(
  File.join(File.dirname(__FILE__), *%w[ .. .. ruote lib ]))
ruote_couch_lib = File.expand_path(
  File.join(File.dirname(__FILE__), *%w[ .. lib ]))

[ ruote_lib, ruote_couch_lib ].each do |lib|
  $:.unshift(lib) unless $:.include?(lib)
end

