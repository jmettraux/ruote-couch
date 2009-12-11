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

      @couch = Rufus::Jig::Couch.get_db(*args)
      @couch = Rufus::Jig::Couch.put_db(*args) unless @couch

      put_options
      put_design_document
    end

    def put (doc)

      @couch.put_doc(doc)
    end

    def get (type, key)

      @couch.get_doc(key)
    end

    def delete (doc)

      @couch.delete_doc(doc)
    end

    def get_many (type, key=nil, opts={})

      options = if l = opts[:limit]
        "&limit=#{l}"
      else
        ''
      end

      r = if key
        # TODO : implement me
      else
        storage.couch.get("_design/ruote/_view/by_type?key=#{type}#{options}")
      end

      r['rows'].collect { |e| e['value'] }
    end

    def purge!

      @couch.delete
    end

    def dump (type)
      #s = "=== #{type} ===\n"
      #@cloche.get_many(type).inject(s) do |s1, e|
      #  s1 << "\n"
      #  e.keys.sort.inject(s1) do |s2, k|
      #    s2 << "  #{k} => #{e[k].inspect}\n"
      #  end
      #end
      ""
    end

    protected

    def put_options

      doc = get('configurations', 'engine') || {
        '_id' => 'engine', 'type' => 'configurations' }

      @ptions = { 'color' => 'yellow' }

      doc.payload.merge!(@options)

      doc.put rescue put_options
        # re-upgrade if the put failed
    end

    def put_design_document

      doc = Rufus::Jig::Json.decode(
        File.read(File.join(File.dirname(__FILE__), 'storage.json')))

      current = @couch.get_doc('_design/ruote')

      if current.nil? || doc['version'] >= (current['version'] || -1)

        current.delete if current
        @couch.put_doc(doc)
      end
    end
  end
end
end

