#--
# Copyright (c) 2005-2011, John Mettraux, jmettraux@gmail.com
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
    def initialize (*args)

      hc = Rufus::Jig::HttpCore.new(*args)
        # leverage the argument parsing logic in there

      @host = hc.host
      @port = hc.port

      @options = hc.options

      @prefix = hc.options['couch_prefix'] || hc.options['prefix'] || ''
      @prefix = "#{@prefix}_" if @prefix.size > 0

      @dbs = {}

      %w[ msgs configurations variables ].each do |type|

        @dbs[type] = Database.new(
          @host, @port, type, "#{@prefix}ruote_#{type}", @options)
      end

      %w[ errors expressions schedules ].each do |type|

        @dbs[type] = WfidIndexedDatabase.new(
          @host, @port, type, "#{@prefix}ruote_#{type}", @options)
      end

      @dbs['workitems'] = WorkitemDatabase.new(
        @host, @port, 'workitems', "#{@prefix}ruote_workitems", @options)

      put_configuration

      @msgs_thread = nil
      @msgs_queue = ::Queue.new
      @msgs_last_min = nil

      @schedules_thread = nil
      @schedules_queue = ::Queue.new
      @schedules = {}
      @schedules_last_min = nil
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

    def dump (type)

      @dbs[type].dump
    end

    def shutdown

      @dbs.values.each { |db| db.shutdown }

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
    def by_participant (type, participant_name, opts)

      raise NotImplementedError if type != 'workitems'

      @dbs['workitems'].by_participant(participant_name, opts)
    end

    def by_field (type, field, value=nil)

      raise NotImplementedError if type != 'workitems'

      @dbs['workitems'].by_field(field, value)
    end

    def query_workitems (criteria)

      count = criteria.delete('count')

      result = @dbs['workitems'].query_workitems(criteria)

      count ? result.size : result.collect { |h| Ruote::Workitem.new(h) }
    end

    # Overwriting Ruote::StorageBase.get_msgs
    #
    # Taking care of using long-polling
    # (http://wiki.apache.org/couchdb/HTTP_database_API) when possible
    #
    def get_msgs

      mt = @msgs_thread

      ensure_msgs_thread_is_running

      msgs = []
      2.times { msgs = get_many('msgs') } if mt != @msgs_thread
        #
        # seems necessary to avoid any msgs leak :-(

      while @msgs_queue.size > 0
        msgs << @msgs_queue.pop
      end

      if msgs.empty? && Time.now.min != @msgs_last_min
        #
        # once per minute, do a regular get, to avoid lost msgs
        #
        msgs = get_many('msgs')
        @msgs_last_min = Time.now.min
      end

      msgs
    end

    def get_schedules (delta, now)

      ensure_schedules_thread_is_running

      while @schedules_queue.size > 0

        deleted, s = @schedules_queue.pop

        next unless s

        if deleted
          @schedules.delete(s['_id'])
        else
          @schedules[s['_id']] = s
        end
      end

      if Time.now.min != @schedules_last_min
        #
        # once per minute, do a regular get, to avoid lost schedules
        #
        @schedules = get_many('schedules')
        @schedules = @schedules.inject({}) { |h, s| h[s['_id']] = s; h }
        @schedules_last_min = Time.now.min
      end

      filter_schedules(@schedules.values.reject { |sch| sch['at'].nil? }, now)
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
        while true # long polling should just run forever so retry if anything goes wrong
          retry_count = 0; last_try = Time.now # keep track of retry attempts
          begin
            @dbs['msgs'].couch.on_change do |_, deleted, doc|
              @msgs_queue << doc unless deleted
            end
          rescue
            # count retries in the last minute only
            (retry_count = 1; last_try = Time.now) if Time.now - last_try > 60
            raise if retry_count > 10 # retry up to 10 times per minute, fail after that
            retry_count += 1
            retry
          end
        end
      end
      
    end

    def ensure_schedules_thread_is_running

      status = @schedules_thread ? @schedules_thread.status : -1
      return if status == 'run' || status == 'sleep'

        
      @schedules_thread = Thread.new do
        while true # long polling should just run forever so retry if anything goes wrong
          retry_count = 0; last_try = Time.now # keep track of retry attempts
          begin
            @dbs['schedules'].couch.on_change do |_, deleted, doc|
              @schedules_queue << [ deleted, doc ]
            end
          rescue
            # count retries in the last minute only
            (retry_count = 1; last_try = Time.now) if Time.now - last_try > 60
            raise if retry_count > 10 # retry up to 10 times per minute, fail after that
            retry_count += 1
            retry
          end
        end
      end
    end
    
  end
end
end

