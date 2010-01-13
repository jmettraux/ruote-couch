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


module Ruote::Couch

  class Database

    attr_reader :type

    def initialize (host, port, type, name, re_put_ok=true)

      @couch = Rufus::Jig::Couch.new(host, port, name, :re_put_ok => re_put_ok)
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

    def get (key)

      @couch.get(key)
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

    def shutdown

      @couch.close
    end

    # Deletes database and closes it.
    #
    def purge!

      @couch.delete('.')
      @couch.close
    end

    # Removes all the documents in this database.
    #
    def purge_docs!

      @couch.delete('.')
      @couch.put('.')
    end

    protected

    def prepare

      # nothing to do for a index-less database
    end

    def query_options (opts)

      if l = opts[:limit]
        "&limit=#{l}"
      else
        ''
      end
    end
  end

  class WfidIndexedDatabase < Database

    BY_WFID_DESIGN_DOC = {
      '_id' => '_design/ruote',
      'version' => 0,
      'views' => {
        #'by_wfid' => { 'map' => 'function (doc) { emit(doc.fei.wfid, doc); }' }
        'by_wfid' => {
          'map' => 'function (doc) { if (doc.fei) emit(doc.fei.wfid, null); }' }
      }
    }

    def get_many (key, opts)

      if key && m = key.source.match(/!?(.+)\$$/)
        # let's use the couch view...

        rs = @couch.get(
          "_design/ruote/_view/by_wfid?key=%22#{m[1]}%22" +
          "&include_docs=true#{query_options(opts)}")

        rs['rows'].collect { |e| e['doc'] }

      else
        # let's use the naive default implementation

        super
      end
    end

    protected

    def prepare

      @couch.delete('_design/ruote')
      @couch.put(BY_WFID_DESIGN_DOC)
    end
  end

  class WorkitemDatabase < WfidIndexedDatabase

    # TODO : write specialized CouchStorageParticipant class ?

    protected

    def prepare

      # TODO : insert special payload view

      super
    end
  end
end

