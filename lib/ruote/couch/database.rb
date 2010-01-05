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

      os = if l = opts[:limit]
        "&limit=#{l}"
      else
        ''
      end

      rs = @couch.get("_all_docs?include_docs=true#{os}")

      rs = rs['rows'].collect { |e| e['doc'] }

      rs = rs.select { |doc| doc['_id'].match(key) } if key
        # naive...

      rs
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

    def purge!

      @couch.delete('.')
      @couch.close
    end

    protected

    def prepare

      # nothing to do for a index-less database
    end
  end

  class WfidIndexedDatabase < Database

    #DESIGN_DOC_TEMPLATE = %{
    #  {
    #    "_id": "_design/ruote",
    #    "version": 0,
    #
    #    "views": {
    #      "by_type": {
    #        "map": "function (doc) { emit(doc.type, doc); }"
    #      }
    #    }
    #  }
    #}.strip

    protected

    def prepare

      # TODO
    end
  end
end

