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


module Ruote::Couch

  #
  # A database corresponds to a Couch database (not a Couch server).
  #
  class Database

    attr_reader :couch

    def initialize(host, port, name, opts={})

      @couch = Rufus::Jig::Couch.new(host, port, name, opts)

      unless @couch.get('.')
        @couch.put('.')
        try_upgrade!
      end

      prepare
    end

    def put(doc, opts)

      doc = doc.dup unless opts[:update_rev]
      doc['put_at'] = Ruote.now_to_utc_s

      @couch.put(doc, :update_rev => opts[:update_rev])
        #
        # :update_rev => true :
        # updating the current doc _rev, this trick allows
        # direct "create then apply" chaining
    end

    def get(key, opts={})

      @couch.get(key, opts)
    end

    def delete(doc)

      r = @couch.delete(doc)

      #p [ :del, doc['_id'], Thread.current.object_id.to_s[-3..-1], r.nil? ]
      Thread.pass
        # without this, test/functional/ct_0 fails after 1 to 10 runs...

      r

    rescue Rufus::Jig::TimeoutError => te
      true
    end

    def get_many(type, key, opts)

      if key.nil? && opts.empty?
        return @couch.query_for_docs("ruote:#{type}")
      end

      if %w( errors expressions schedules workitems ).include?(type) && key.is_a?(String)
        return @couch.query_for_docs("ruote:#{type}_by_wfid", :key => key)
      end

      is = ids(type)

      return is.length if opts[:count]
      return [] if is.empty?

      is = is.reverse if opts[:descending]

      if key
        keys = Array(key).map { |k| k.is_a?(String) ? "!#{k}" : k }
        is = is.select { |i| Ruote::StorageBase.key_match?(keys, i) }
      end

      skip = opts[:skip] || 0
      limit = opts[:limit] || is.length

      is = is[skip, limit]

      #return [] if is.empty?
        # not necessary at this point, jig provides already this optimization.

      @couch.query_for_docs("ruote:#{type}", :keys => is)
    end

    # Returns a sorted list of the ids of all the docs in this database
    # of the given type.
    #
    def ids(type)

      @couch.
        query("ruote:#{type}", :include_docs => false).
        map { |row| row['id'] }
    end

    def dump(type)

      s = "=== #{type} ===\n"

      get_many(type, nil, {}).inject(s) do |s1, e|
        s1 << "\n"
        e.keys.sort.inject(s1) do |s2, k|
          s2 << "  #{k}: #{e[k]}\n"
        end
      end
    end

    # Makes sure to close the HTTP connection down.
    #
    def shutdown

      @couch.close
    end

    # Deletes all the documents in this database.
    #
    def purge!

      docs = @couch.all(:include_docs => false, :include_design_docs => false)
      @couch.bulk_delete(docs)
    end

    def purge_type!(type)

      docs = @couch.query_for_docs("ruote:#{type}", :include_docs => false, :include_design_docs => false)
      @couch.bulk_delete(docs)
    end

    # Used by WorkitemDatabase#query
    #
    def by_wfid(wfid, opts)

      res = get_many('workitems', wfid, opts)

      res.is_a?(Array) ? res.collect { |doc| Ruote::Workitem.new(doc) } : res
    end

    #--
    #def try (&block)
    #  try = 0
    #  begin
    #    try = try + 1
    #    block.call
    #  rescue Rufus::Jig::HttpError => he
    #    raise he
    #  rescue
    #    retry unless try > 1
    #  end
    #end
      # keeping it frozen for now
      #++

    # This method is called by Storage#by_field
    #
    def by_field(field, value, opts)

      docs = @couch.query_for_docs(
        'ruote:workitems_by_field',
        opts.merge(
          :key => value ? { field => value } : field,
          :skip => opts[:offset] || opts[:skip],
          :limit => opts[:limit]))

      opts[:count] ? docs.size : docs.collect { |h| Ruote::Workitem.new(h) }
    end

    # This method is called by #query_workitems and Storage#by_participant
    #
    def by_participant(name, opts)

      docs = @couch.query_for_docs(
        'ruote:workitems_by_participant_name',
        opts.merge(
          :key => name,
          :skip => opts[:offset] || opts[:skip],
          :limit => opts[:limit]))

      opts[:count] ? docs.size : docs.collect { |h| Ruote::Workitem.new(h) }
    end

    # This method is called by Storage#query
    #
    def query_workitems(criteria)

      opts = {
        :skip => criteria.delete('offset') || criteria.delete('skip'),
        :limit => criteria.delete('limit')
      }

      wfid =
        criteria.delete('wfid')
      pname =
        criteria.delete('participant_name') || criteria.delete('participant')

      if criteria.empty?
        return by_participant(pname, opts) if pname
        return by_wfid(wfid, opts) if wfid
        return get_many('workitems', nil, opts).collect { |hwi| Ruote::Workitem.new(hwi) }
      end

      cr = criteria.collect { |fname, fvalue| { fname => fvalue } }

      hwis = @couch.query_for_docs('ruote:workitems_by_field', opts.merge(:keys => cr))

      hwis = hwis.select { |hwi|
        hwi['fei']['wfid'] == wfid
      } if wfid

      hwis = hwis.select { |hwi|
        Ruote::StorageParticipant.matches?(hwi, pname, criteria)
      }

      hwis.collect { |hwi| Ruote::Workitem.new(hwi) }
    end


    # Returns the design document that goes with this class of database
    #
    def self.design_doc

      self.allocate.send(:design_doc)
    end

    protected

    def prepare

      d = @couch.get(design_doc['_id'])

      return if d && d['views'] == design_doc['views']

      d ||= design_doc
      d['views'] = design_doc['views']

      @couch.put(d)
    end

    def try_upgrade!

      dbs = types.map do |type|

        # Check whether the old databases exists..
        name = [@couch.name, type].join('_')
        db = Rufus::Jig::Couch.new(
          @couch.http.host, @couch.http.port, name, @couch.http.options)

        db if db.get('.')
      end

      # If all dbs exist, then copy over the data from them.
      if dbs.all?

        dbs.each do |db|

          db.all(:include_docs => true, :include_design_docs => false).each do |doc|

            doc.delete('_rev')
            @couch.put doc
          end

          db.delete '.'

        end
      end

    end

    def types
      %w( configurations errors expressions msgs schedules variables workitems )
    end

    def type_views
      types.inject({}) do |h, type|
        h.update(type => {
          'map' => %{ function(doc) { if (doc.type == '#{type}') emit (doc._id, 1); } }
        })
      end
    end

    def design_doc
      @design_doc ||= {
        '_id' => '_design/ruote',

        'language' => 'javascript',

        'views' => {
          'errors_by_wfid' => {
            'map' => %{ function (doc) { if (doc.type == 'errors' && doc.fei) emit(doc.fei.wfid, 1); } }
          },

          'expressions_by_wfid' => {
            'map' => %{ function (doc) { if (doc.type == 'expressions' && doc.fei) emit(doc.fei.wfid, 1); } }
          },

          'schedules_by_wfid' => {
            'map' => %{ function (doc) { if (doc.type == 'schedules' && doc.owner) emit(doc.owner.wfid, 1); } }
          },

          'workitems_by_wfid' => {
            'map' => %{ function (doc) { if (doc.type == 'workitems') emit(doc.wfid, 1); } }
          },

          # NOTE : with 'by_field', for a workitem with N fields there are
          # currently 2 * N rows generated per workitem.
          #
          # Why not restrict { field => value } keys to only fields whose value
          # is a string, a boolean or null ? I have the impression that querying
          # for field whose value is 'complex' (array or hash) is not necessary
          # (though sounding crazy useful).
          'workitems_by_field' => {
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
          },

          'workitems_by_participant_name' => {
            'map' => %{
              function (doc) {
                if (doc.participant_name) {
                  emit(doc.participant_name, null);
                }
              }
            }
          }

        }.merge(type_views)
      }
    end

  end
end

