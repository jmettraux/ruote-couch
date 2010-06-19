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

require 'thread'
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
    # added to all the database names used by this storage. 'prefix' is accepted
    # as well.
    #
    def initialize (host, port, options={})

      @host = host
      @port = port

      @options = options

      @prefix = options['couch_prefix'] || options['prefix'] || ''
      @prefix = "#{@prefix}_" if @prefix.size > 0

      @dbs = {}

      %w[ msgs schedules configurations variables ].each do |type|

        @dbs[type] = Database.new(
          @host, @port, type, "#{@prefix}ruote_#{type}")
      end

      @dbs['errors'] = WfidIndexedDatabase.new(
        @host, @port, 'errors', "#{@prefix}ruote_errors")

      @dbs['expressions'] = WfidIndexedDatabase.new(
        #@host, @port, 'expressions', "#{@prefix}ruote_expressions", false)
        @host, @port, 'expressions', "#{@prefix}ruote_expressions")

      @dbs['workitems'] = WorkitemDatabase.new(
        @host, @port, 'workitems', "#{@prefix}ruote_workitems")

      put_configuration

      @msgs_thread = nil
      @msgs_queue = ::Queue.new

      @schedules_thread = nil
      @schedules_queue = ::Queue.new
      @schedules = nil
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
      #@dbs.values.each { |db| db.shutdown }
    end

    # Used when doing integration tests, removes all
    # msgs, schedules, errors, expressions and workitems.
    #
    # NOTE that it doesn't remove engine variables (danger)
    #
    def clear

      %w[ msgs schedules errors expressions workitems ].each do |type|
        @dbs[type].purge!
      end
    end

    def dump (type)

      @dbs[type].dump
    end

    def shutdown

      #@dbs.values.each { |db| db.shutdown }

      #@poller.kill if @poller

      @msgs_thread.kill rescue nil
      @schedules_thread.kill rescue nil
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type (type)

      @dbs[type] = Database.new(
        #@host, @port, type, "#{@prefix}ruote_#{type}", false)
        @host, @port, type, "#{@prefix}ruote_#{type}")
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type! (type)

      if db = @dbs[type]
        db.purge!
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

      ensure_msgs_thread_is_running

      msgs = []

      while @msgs_queue.size > 0
        msgs << @msgs_queue.pop
      end

      msgs
    end

    def get_schedules (delta, now)

      ensure_schedules_thread_is_running

      if @schedules.nil?

        # NOTE : the problem with this approach is that ALL the schedules
        # are stored in memory. Most of the time it's not a problem, but
        # for people will lots of schedules...

        @schedules = get_many('schedules')
        @schedules = @schedules.inject({}) { |h, s| h[s['_id']] = s; h }
      end

      while @schedules_queue.size > 0

        deleted, s = @schedules_queue.pop

        if deleted
          @schedules.delete(s['_id'])
        else
          @schedules[s['_id']] = s
        end
      end

      filter_schedules(@schedules.values, now)
    end

    protected

    def put_configuration

      return if get('configurations', 'engine')

      conf = { '_id' => 'engine', 'type' => 'configurations' }.merge!(@options)

      put(conf)
    end

    def ensure_msgs_thread_is_running

      status = @msgs_thread ? @msgs_thread.status : -1
      return if status == 'run' || status == 'sleep'

      @msgs_thread = Thread.new do
        @dbs['msgs'].couch.on_change do |_, deleted, doc|
          @msgs_queue << doc unless deleted
        end
      end
    end

    def ensure_schedules_thread_is_running

      status = @schedules_thread ? @schedules_thread.status : -1
      return if status == 'run' || status == 'sleep'

      @schedules_thread = Thread.new do
        @dbs['schedules'].couch.on_change do |_, deleted, doc|
          @schedules_queue << [ deleted, doc ]
        end
      end
    end
  end
end
end

