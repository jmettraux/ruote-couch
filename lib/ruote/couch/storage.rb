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
require 'rufus/jig' # gem install 'rufus-jig'


module Ruote
module Couch

  class CouchStorage

    include Ruote::StorageBase

    attr_reader :couch

    def initialize (*args)

      @options = args.last.is_a?(Hash) ? args.pop : {}

      @couch = Rufus::Jig::Couch.new(*args)
      @couch.put('.') unless @couch.get('.')

      put_configuration
      put_design_document
    end

    def put (doc, opts={})

      doc['put_at'] = Ruote.now_to_utc_s

      r = @couch.put(doc, :update_rev => opts[:update_rev])
        #
        # :update_rev => true :
        # updating the current doc _rev, this trick allows
        # direct "create then apply" chaining

      r ? @couch.get(doc['_id']) : nil
    end

    def get (type, key)

      @couch.get(key)
    end

    def delete (doc)

      @couch.delete(doc)
    end

    def get_many (type, key=nil, opts={})

      os = if l = opts[:limit]
        "&limit=#{l}"
      else
        ''
      end

      rs = if key
        # TODO : implement me
        @couch.get("_design/ruote/_view/by_type?key=%22#{type}%22#{os}")
      else
        @couch.get("_design/ruote/_view/by_type?key=%22#{type}%22#{os}")
      end

      rs['rows'].collect { |e| e['value'] } rescue []
    end

    def purge!

      @couch.delete('.')
    end

    def dump (type)

      s = "=== #{type} ===\n"

      get_many(type).inject(s) do |s1, e|
        s1 << "\n"
        e.keys.sort.inject(s1) do |s2, k|
          s2 << "  #{k} => #{e[k].inspect}\n"
        end
      end
    end

    protected

    def put_configuration

      return if @couch.get('engine')

      conf = { '_id' => 'engine', 'type' => 'configurations' }.merge!(@options)

      @couch.put(conf)
    end

    def put_design_document

      doc = Rufus::Jig::Json.decode(
        File.read(File.join(File.dirname(__FILE__), 'storage.json')))

      current = @couch.get('_design/ruote')

      if current.nil? || doc['version'] >= (current['version'] || -1)

        @couch.delete(current) if current
        @couch.put(doc)
      end
    end
  end
end
end

