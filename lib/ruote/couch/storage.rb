#--
# Copyright (c) 2005-2012, John Mettraux, jmettraux@gmail.com
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
  class Storage

    include Ruote::StorageBase

    # Hooks the storage to a CouchDB instance.
    #
    # The main option is 'couch_prefix', which indicate which prefix should be
    # added to the database name used by this storage. 'prefix' is accepted
    # as well.
    #
    def initialize(*args)

      hc = Rufus::Jig::HttpCore.new(*args)
        # leverage the argument parsing logic in there

      @host = hc.host
      @port = hc.port

      @options = hc.options

      name = [
	hc.options['couch_prefix'] || hc.options['prefix'], 'ruote'
      ].compact.join('_')

      @db = Database.new(@host, @port, name, @options)

      replace_engine_configuration(@options)

      @poll_thread = nil

      @msgs_queue = ::Queue.new
      @msgs_last_min = nil

      @schedules_queue = ::Queue.new
      @schedules = {}
      @schedules_last_min = nil
    end

    def put(doc, opts={})

      @db.put(doc, opts)
    end

    def get(type, key)

      @db.get(key)
    end

    def delete(doc)

      @db.delete(doc)
    end

    def get_many(type, key=nil, opts={})

      @db.get_many(type, key, opts)
    end

    def ids(type)

      @db.ids(type)
    end

    def purge!

      @db.purge!
    end

    def dump(type)

      @db.dump(type)
    end

    def shutdown

      @db.shutdown
      @poll_thread.kill rescue nil
    end

    # This storage can add new types on the fly.
    #
    def add_type(type)
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type!(type)

      @db.purge_type!(type)
    end

    # A provision made for workitems, allow to query them directly by
    # participant name.
    #
    def by_participant(type, participant_name, opts)

      raise NotImplementedError if type != 'workitems'

      @db.by_participant(participant_name, opts)
    end

    def by_field(type, field, value, opts={})

      raise NotImplementedError if type != 'workitems'

      @db.by_field(field, value, opts)
    end

    def by_wfid(type, wfid, opts)

      raise NotImplementedError if type != 'workitems'

      @db.by_wfid(wfid, opts)
    end

    def query_workitems(criteria)

      count = criteria.delete('count')
      res = @db.query_workitems(criteria)

      count ? res.size : res
    end

    # Overwriting Ruote::StorageBase.get_msgs
    #
    # Taking care of using long-polling
    # (http://wiki.apache.org/couchdb/HTTP_database_API) when possible
    #
    # The worker argument is not used in this storage implementation.
    #
    def get_msgs

      mt = @poll_thread

      ensure_poll_thread_is_running

      msgs = []
      2.times {
        (msgs = get_many('msgs')) rescue nil
      } if mt != @poll_thread
        #
        # seems necessary to avoid any msgs leak :-(
        #
        # added the "rescue nil", to rescue timeout exceptions

      while @msgs_queue.size > 0
        msgs << @msgs_queue.pop
      end

      if msgs.empty? && Time.now.min != @msgs_last_min
        #
        # once per minute, do a regular get, to avoid lost msgs
        #
        begin
          msgs = get_many('msgs')
          @msgs_last_min = Time.now.min
        rescue Rufus::Jig::TimeoutError => te
        end
      end

      msgs
    end

    def get_schedules(delta, now)

      ensure_poll_thread_is_running

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

    def ensure_poll_thread_is_running

      if t = @poll_thread
        return if t.status == 'run' || t.status == 'sleep' # thread is OK
      end

      # create or revive thread....

      @poll_thread = Thread.new do

        @db.couch.on_change do |_, deleted, doc|
          # FIXME http://docs.couchdb.org/en/latest/couchapp/ddocs.html#filterfun
          #
          case doc['type']
          when 'msgs'      then @msgs_queue << doc unless deleted

          when 'schedules' then @schedules_queue << [ deleted, doc ]

          end
        end
      end
    end

  end

  #
  # Kept for backward compatibility.
  #
  class CouchStorage < Storage
  end
end
end

