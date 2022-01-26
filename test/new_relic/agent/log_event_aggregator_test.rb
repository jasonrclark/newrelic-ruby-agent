# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'data_container_tests'))

require 'new_relic/agent/log_event_aggregator'

module NewRelic::Agent
  class LogEventAggregatorTest < Minitest::Test
    def setup
      nr_freeze_process_time
      @aggregator = NewRelic::Agent.agent.log_event_aggregator
      @aggregator.reset!
    end

    # TODO: Fix to use logging specific limit when wired up!
    CONFIG_KEY = :'custom_insights_events.max_samples_stored'

    # Helpers for DataContainerTests

    def create_container
      @aggregator
    end

    def populate_container(container, n)
      n.times do |i|
        container.record("A log message", ::Logger::Severity.constants.sample.to_s)
      end
    end

    include NewRelic::DataContainerTests

    def test_record_by_default_limit
      max_samples = NewRelic::Agent.config[CONFIG_KEY]
      n = max_samples + 1
      n.times do |i|
        @aggregator.record("Take it to the limit", "FATAL")
      end

      metadata, results = @aggregator.harvest!
      assert_equal(n, metadata[:seen])
      assert_equal(max_samples, metadata[:capacity])
      assert_equal(max_samples, metadata[:captured])
      assert_equal(max_samples, results.size)
    end

    def test_record_in_transaction
      max_samples = NewRelic::Agent.config[CONFIG_KEY]
      n = max_samples + 1
      n.times do |i|
        in_transaction do
          @aggregator.record("Take it to the limit", "FATAL")
        end
      end

      metadata, results = @aggregator.harvest!
      assert_equal(n, metadata[:seen])
      assert_equal(max_samples, metadata[:capacity])
      assert_equal(max_samples, metadata[:captured])
      assert_equal(max_samples, results.size)
    end

    def test_lowering_limit_truncates_buffer
      orig_max_samples = NewRelic::Agent.config[CONFIG_KEY]

      orig_max_samples.times do |i|
        @aggregator.record("Truncation happens", "WARN")
      end

      new_max_samples = orig_max_samples - 10
      with_config(CONFIG_KEY => new_max_samples) do
        metadata, results = @aggregator.harvest!
        assert_equal(new_max_samples, metadata[:capacity])
        assert_equal(orig_max_samples, metadata[:seen])
        assert_equal(new_max_samples, results.size)
      end
    end

    def test_record_adds_timestamp
      t0 = Process.clock_gettime(Process::CLOCK_REALTIME)
      message = "Time keeps slippin' away"
      @aggregator.record(message, "INFO")

      _, events = @aggregator.harvest!

      assert_equal(1, events.size)
      event = events.first

      assert_equal([
        {
          'priority' => 1,
        },
        {
          'level' => "INFO",
          'message' => message,
          'timestamp' => t0,
        }
      ],
      event)
    end

    def test_records_metrics_on_harvest
      with_config CONFIG_KEY => 5 do
        engine = NewRelic::Agent.instance.stats_engine
        engine.reset!

        9.times { @aggregator.record("Are you counting this?", "DEBUG") }
        @aggregator.harvest!

        assert_metrics_recorded_exclusive({
          "Logging/lines" => { :call_count => 9 },
          "Logging/lines/DEBUG" => { :call_count => 9 },
          "Supportability/Logging/Customer/Seen" => { :call_count => 9 },
          "Supportability/Logging/Customer/Sent" => { :call_count => 5 },
          "Supportability/Logging/Customer/Dropped" => { :call_count => 4 },
        },
        :ignore_filter => %r{^Supportability/API/})
      end
    end


    def test_basic_conversion_to_melt_format
      log_data = [
        {
          seen: 0,
          captured: 0,
          linking: {
            "entity.name": "Hola"
          }
        },
        [
          [{ "priority": 1}, { "message": "This is a mess" }]
        ]
      ]

      payload, size = LogEventAggregator.payload_to_melt_format(log_data)
      expected = [{
        common: { attributes: { "entity.name": "Hola" } },
        logs: [{"message": "This is a mess"}]
      }]

      assert_equal 1, size
      assert_equal expected, payload
    end
  end
end
