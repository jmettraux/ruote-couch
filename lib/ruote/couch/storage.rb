#--
# Copyright (c) 2005-2010, John Mettraux, jmettraux@gmail.com
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

  #
  # A CouchDB storage mechanism for ruote.
  #
  # The storage merely 'routes' work to Ruote::Couch::Database instances,
  # one per document 'type' (expressions, msgs, schedules, variables, ...)
  #
  class CouchStorage

    include Ruote::StorageBase

    attr_reader :couch

    # Hooks the storage to a CouchDB instance.
    #
    # The main option is 'couch_prefix', which indicate which prefix should be
    # added to all the database names used by this storage.
    #
    # The option 'couch_timeout' is used what is the get_msgs timeout. This
    # is the long-polling timeout. For functional test it is set to two seconds
    # but for a production system, something like 10 minutes or 8 hours might
    # be OK.
    #
    def initialize (host, port, options={})

      @host = host
      @port = port

      @options = options

      @prefix = options['couch_prefix'] || options['prefix'] || ''
      @prefix = "#{@prefix}_" if @prefix.size > 0

      @zeroes = 21 # maybe make it an option
      @timeout = options['couch_timeout'] || 60

      @dbs = {}

      %w[ msgs schedules configurations variables ].each do |type|

        @dbs[type] = Database.new(
          @host, @port, type, "#{@prefix}ruote_#{type}")
      end

      @dbs['errors'] = WfidIndexedDatabase.new(
        @host, @port, 'errors', "#{@prefix}ruote_errors")

      @dbs['expressions'] = WfidIndexedDatabase.new(
        @host, @port, 'expressions', "#{@prefix}ruote_expressions", false)

      @dbs['workitems'] = WorkitemDatabase.new(
        @host, @port, 'workitems', "#{@prefix}ruote_workitems")

      put_configuration

      @zero_msgs_offset = @zeroes
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

    def ids (type)

      @dbs[type].ids
    end

    def purge!

      @dbs.values.each { |db| db.purge! }
    end

    def dump (type)

      @dbs[type].dump
    end

    def shutdown

      @poller.kill if @poller

      @dbs.values.each { |db| db.shutdown }
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type (type)

      @dbs[type] = Database.new(
        @host, @port, type, "#{@prefix}ruote_#{type}", false)
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type! (type)

      if db = @dbs[type]
        db.purge_docs!
      end
    end

    # A provision made for workitems, allow to query them directly by
    # participant name.
    #
    def by_participant (type, participant_name)

      raise NotImplementedError if type != 'workitems'

      @dbs['workitems'].by_participant(participant_name)
    end

    def by_field (type, field, value=nil)

      raise NotImplementedError if type != 'workitems'

      @dbs['workitems'].by_field(field, value)
    end

    def query_workitems (criteria)

      @dbs['workitems'].query_workitems(criteria)
    end

    # Overwriting Ruote::StorageBase.get_msgs
    #
    # Taking care of using long-polling
    # (http://wiki.apache.org/couchdb/HTTP_database_API) when possible
    #
    def get_msgs

      if @zero_msgs_offset > 0

        msgs = get_many(
          'msgs', nil, :limit => 300
        ).sort { |a, b|
          a['put_at'] <=> b['put_at']
        }

        @zero_msgs_offset = @zero_msgs_offset - 1 if msgs.size == 0
        return msgs
      end

      @zero_msgs_offset = @zeroes

      schedules = get_many('schedules')

      next_at = schedules.collect { |s| s['at'] }.sort.first
      delta = next_at ? (Time.parse(next_at) - Time.now) : nil

      #p [ delta, @timeout ]

      return [] if delta && delta < 5.0

      last_seq = @dbs['msgs'].get('_changes')['last_seq']

      timeout = delta ? delta - 3.0 : -1.0
      timeout = (timeout < 0.0 || timeout > @timeout) ? @timeout : timeout

      #p [ Time.now, :last_seq, last_seq, :timeout, timeout ]

      begin

        @poller = Thread.current

        @dbs['msgs'].get(
          "_changes?feed=longpoll&heartbeat=60000&since=#{last_seq}",
          :timeout => timeout)
            # block until there is a change in the 'msgs' db

      rescue Exception => e
      #rescue Rufus::Jig::TimeoutError => te
      #  p [ :caught, e.class ]
      #  e.backtrace.each { |l| puts l }
      ensure
        @poller = nil
      end

      []
    end

    protected

    def put_configuration

      return if get('configurations', 'engine')

      conf = { '_id' => 'engine', 'type' => 'configurations' }.merge!(@options)

      put(conf)
    end
  end
end
end

