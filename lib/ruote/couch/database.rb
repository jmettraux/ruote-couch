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

require 'cgi'


module Ruote::Couch

  #
  # A database corresponds to a Couch database (not a Couch server).
  #
  # There is one database per ruote document type (msgs, workitems,
  # expressions, ...)
  #
  class Database

    attr_reader :type

    def initialize (host, port, type, name, re_put_ok=true)

      opts = { :re_put_ok => re_put_ok }
      #opts[:timeout] = TODO

      @couch = Rufus::Jig::Couch.new(host, port, name, opts)

      @couch.put('.') unless @couch.get('.')

      @type = type

      prepare
    end

    def put (doc, opts)

      doc['put_at'] = Ruote.now_to_utc_s

      @couch.put(doc, :update_rev => opts[:update_rev])
        #
        # :update_rev => true :
        # updating the current doc _rev, this trick allows
        # direct "create then apply" chaining
    end

    def get (key, opts={})

      @couch.get(key, opts)
    end

    def delete (doc)

      @couch.delete(doc)
    end

    def get_many (key, opts)

      rs = @couch.get("_all_docs?include_docs=true#{query_options(opts)}")

      rs = rs['rows'].collect { |e| e['doc'] }

      rs = rs.select { |doc| doc['_id'].match(key) } if key
        # naive...

      rs.select { |doc| ! doc['_id'].match(/^\_design\//) }
    end

    # Returns a sorted list of the ids of all the docs in this database.
    #
    def ids

      rs = @couch.get('_all_docs')

      rs['rows'].collect { |r| r['id'] }
    end

    def dump

      s = "=== #{@type} ===\n"

      get_many(nil, {}).inject(s) do |s1, e|
        s1 << "\n"
        e.keys.sort.inject(s1) do |s2, k|
          s2 << "  #{k} => #{e[k].inspect}\n"
        end
      end
    end

    #def shutdown
    #  @couch.close
    #end
      # jig > 0.1.17 is OK without that

    # Deletes all the documents in this database.
    #
    def purge!

      @couch.get('_all_docs')['rows'].each do |row|
        doc = { '_id' => row['id'], '_rev' => row['value']['rev'] }
        @couch.delete(doc) unless doc['_id'].match(/^\_design\//)
      end
        #
        # which is faster than
        #
      #@couch.delete('.')
      #@couch.put('.')
      #@couch.http.cache.clear
    end

    protected

    def prepare

      # nothing to do for a index-less database
    end

    # (for now, the only option is :limit)
    #
    def query_options (opts)

      opts = opts.select { |k, v| [ :limit, :skip ].include?(k) && v != nil }

      s = opts.collect { |k, v| "#{k}=#{v}" }.join('&')

      s.length > 0 ? "&#{s}" : ''
    end

    def query (uri)

      rs = @couch.get(uri)

      rs['rows'].collect { |e| e['doc'] }
    end

    def query_by_post (uri, keys)

      keys = { 'keys' => keys }

      rs = @couch.post(uri, keys)

      rs['rows'].collect { |e| e['doc'] }.uniq
    end
  end

  #
  # A Couch database with a by_wfid view.
  #
  class WfidIndexedDatabase < Database

    def get_many (key, opts)

      if key && m = key.source.match(/!?(.+)\$$/)
        # let's use the couch view...

        query(
          "_design/ruote/_view/by_wfid?key=%22#{m[1]}%22" +
          "&include_docs=true#{query_options(opts)}")

      else
        # let's use the naive default implementation

        super
      end
    end

    # Used by WorkitemDatabase#query
    #
    def by_wfid (wfid)

      get_many(/!#{wfid}$/, {})
    end

    # Returns the design document that goes with this class of database
    #
    def self.design_doc

      self.allocate.send(:design_doc)
    end

    protected

    def design_doc

      {
        '_id' => '_design/ruote',
        'views' => {
          'by_wfid' => {
            'map' =>
              'function (doc) { if (doc.fei) emit(doc.fei.wfid, null); }'
          }
        }
      }
    end

    def prepare

      d = @couch.get('_design/ruote')
      @couch.delete(d) if d
      @couch.put(design_doc)
    end
  end

  #
  # A Couch database with a by_wfid view and a by_field view.
  #
  class WorkitemDatabase < WfidIndexedDatabase

    # This method is called by CouchStorage#by_field
    #
    def by_field (field, value=nil, opts={})

      field = { field => value } if value
      field = CGI.escape(Rufus::Json.encode(field))

      query(
        "_design/ruote/_view/by_field?key=#{field}" +
        "&include_docs=true#{query_options(opts)}")
    end

    # This method is called by CouchStorage#by_participant
    #
    def by_participant (name, opts={})

      query(
        "_design/ruote/_view/by_participant_name?key=%22#{name}%22" +
        "&include_docs=true#{query_options(opts)}")
    end

    # This method is called by CouchStorage#query
    #
    def query_workitems (criteria)

      offset = criteria.delete('offset')
      limit = criteria.delete('limit')

      wfid =
        criteria.delete('wfid')
      pname =
        criteria.delete('participant_name') || criteria.delete('participant')

      if criteria.empty? && (wfid.nil? ^ pname.nil?)
        return by_participant(pname) if pname
        return by_wfid(wfid) # if wfid
      end

      return get_many(nil, {}).collect { |hwi| Ruote::Workitem.new(hwi) } \
        if criteria.empty?

      cr = criteria.collect { |fname, fvalue| { fname => fvalue } }

      opts = { :skip => offset, :limit => limit }

      hwis = query_by_post(
        "_design/ruote/_view/by_field?include_docs=true#{query_options(opts)}",
        cr)

      hwis = hwis.select { |hwi| hwi['fei']['wfid'] == wfid } if wfid

      hwis = hwis.select { |hwi|
        Ruote::StorageParticipant.matches?(hwi, pname, criteria) }

      hwis.collect { |hwi| Ruote::Workitem.new(hwi) }
    end

    # Returns the design document that goes with this class of database
    #
    def self.design_doc

      self.allocate.send(:design_doc)
    end

    protected

    def design_doc

      doc = super

      # NOTE : with 'by_field', for a workitem with N fields there are
      # currently 2 * N rows generated per workitem.
      #
      # Why not restrict { field => value } keys to only fields whose value
      # is a string, a boolean or null ? I have the impression that querying
      # for field whose value is 'complex' (array or hash) is not necessary
      # (though sounding crazy useful).

      doc['views']['by_field'] = {
        'map' => %{
          function(doc) {
            if (doc.fields) {
              for (var field in doc.fields) {

                emit(field, null);

                var entry = {};
                entry[field] = doc.fields[field]
                emit(entry, null);
                  //
                  // have to use that 'entry' trick...
                  // else the field is named 'field'
              }
            }
          }
        }
      }
      doc['views']['by_participant_name'] = {
        'map' => %{
          function (doc) {
            if (doc.participant_name) {
              emit(doc.participant_name, null);
            }
          }
        }
      }

      doc
    end
  end
end

