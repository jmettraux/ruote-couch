
#
# testing ruote-couch
#
# Fri Mar 12 17:15:27 JST 2010
#

require File.join(File.dirname(__FILE__), 'base')


class FtLongPollingTest < Test::Unit::TestCase

  def setup

    @engine =
      Ruote::Engine.new(
        Ruote::Worker.new(
          Ruote::Couch::CouchStorage.new(
            '127.0.0.1',
            5984,
            'couch_prefix' => 'test', 'couch_timeout' => 2 * 60)))
  end

  def teardown

    @engine.shutdown
    @engine.context.storage.purge!
  end

  def test_wait

    trace = []

    @engine.register_participant '.+' do |workitem|
      trace << Time.now
    end

    pdef = Ruote.process_definition do
      sequence do
        alpha
        wait :for => '3m'
        bravo
      end
    end

    @engine.context.logger.noisy = true

    wfid = @engine.launch(pdef)

    sleep 15
    assert_equal 1, trace.size

    assert_not_nil @engine.context.storage.instance_variable_get(:@poller)

    @engine.wait_for(wfid)

    p trace

    assert_equal 2, trace.size

    delta = trace.last - trace.first

    assert_in_delta 3.0 * 60, delta, 1.0
  end
end

