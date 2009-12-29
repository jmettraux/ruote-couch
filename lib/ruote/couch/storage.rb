#--
# Copyright (c) 2005-2009, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++

require 'ruote/storage/base'
require 'ruote/couch/version'
require 'ruote/couch/database'
require 'rufus/jig' # gem install rufus-jig


module Ruote
module Couch

  class CouchStorage

    include Ruote::StorageBase

    attr_reader :couch

    def initialize (host, port, options={})

      @host = host
      @port = port

      @options = options

      @prefix = options['prefix'] || ''
      @prefix = "#{@prefix}_" if @prefix.size > 0

      @dbs = {}

      %w[ msgs schedules configurations variables ].each do |type|

        @dbs[type] = Database.new(
          @host, @port, type, "#{@prefix}ruote_#{type}")
      end

      %w[ errors workitems ].each do |type|

        @dbs[type] = WfidIndexedDatabase.new(
          @host, @port, type, "#{@prefix}ruote_#{type}")
      end

      @dbs['expressions'] = WfidIndexedDatabase.new(
        @host, @port, 'expressions', "#{@prefix}ruote_expressions", false)

      put_configuration
    end

    def put (doc, opts={})

      @dbs[doc['type']].put(doc, opts)
    end

    def get (type, key)

      @dbs[type].get(key)
    end

    def delete (doc)

      db = @dbs[doc['type']]

      raise ArgumentError.new("no database for type '#{doc['type']}'") unless db

      db.delete(doc)
    end

    def get_many (type, key=nil, opts={})

      @dbs[type].get_many(key, opts)
    end

    def purge!

      @dbs.values.each { |db| db.purge! }
    end

    def dump (type)

      @dbs[type].dump
    end

    def shutdown

      @dbs.values.each { |db| db.shutdown }
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_test_type (type)

      @dbs[type] = Database.new(
        @host, @port, type, "#{@prefix}ruote_#{type}", false)
    end

    protected

    def put_configuration

      return if get('configurations', 'engine')

      conf = { '_id' => 'engine', 'type' => 'configurations' }.merge!(@options)

      put(conf)
    end

#    def put_design_document
#
#      doc = Rufus::Jig::Json.decode(
#        File.read(File.join(File.dirname(__FILE__), 'storage.json')))
#
#      current = @couch.get('_design/ruote')
#
#      if current.nil? || doc['version'] >= (current['version'] || -1)
#
#        @couch.delete(current) if current
#        @couch.put(doc)
#      end
#    end
  end
end
end

