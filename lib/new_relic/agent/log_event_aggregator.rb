# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.

require 'new_relic/agent/event_aggregator'
require 'new_relic/agent/log_event_buffer'

module NewRelic
  module Agent
    class LogEventAggregator < EventAggregator

      # Common keys
      PLUGIN_TYPE_KEY = "plugin.type".freeze
      PLUGIN_TYPE = "nr-ruby_agent".freeze

      # Per-message keys
      LEVEL_KEY = "level".freeze
      MESSAGE_KEY = "message".freeze
      TIMESTAMP_KEY = "timestamp".freeze

      named :LogEventAggregator
      capacity_key :'log_sending.max_samples_stored'
      enabled_key :'log_sending.enabled'
      buffer_class LogEventBuffer

      def record(formatted_message, severity)
        return unless enabled?

        event = NewRelic::Agent.linking_metadata_transaction
        event[LEVEL_KEY] = severity
        event[MESSAGE_KEY] = formatted_message
        event[TIMESTAMP_KEY] =  Process.clock_gettime(Process::CLOCK_REALTIME)

        stored = @lock.synchronize do
          @buffer.append(event)
        end
        stored
      end

      private

      # Slightly awkward, but we want the base harvest but without
      # this method altering the metadata we gather...
      def reservoir_metadata metadata
        metadata
      end

      # TODO: Because we don't have a fast harvest config key for this type
      # yet, we piggyback on the custom event key.
      def register_capacity_callback
        NewRelic::Agent.config.register_callback(:'custom_insights_events.max_samples_stored') do |max_samples|
          NewRelic::Agent.logger.debug "#{self.class.named} max_samples set to #{max_samples}"
          @lock.synchronize do
            @buffer.capacity = max_samples
          end
        end
      end

      def after_harvest metadata
        linking = NewRelic::Agent.linking_metadata_service
        linking[PLUGIN_TYPE_KEY] = PLUGIN_TYPE
        metadata[:linking] = linking

        dropped_count = metadata[:seen] - metadata[:captured]
        note_dropped_events(metadata[:seen], dropped_count)
        record_supportability_metrics(metadata[:seen], metadata[:captured], dropped_count)
      end

      def note_dropped_events total_count, dropped_count
        if dropped_count > 0
          NewRelic::Agent.logger.warn("Dropped #{dropped_count} log events out of #{total_count}.")
        end
      end

      def record_supportability_metrics total_count, captured_count, dropped_count
        engine = NewRelic::Agent.instance.stats_engine
        engine.tl_record_unscoped_metrics("Supportability/Logging/Customer/Seen") { |stats| stats.increment_count(total_count) }
        engine.tl_record_unscoped_metrics("Supportability/Logging/Customer/Sent") { |stats| stats.increment_count(captured_count) }
        engine.tl_record_unscoped_metrics("Supportability/Logging/Customer/Dropped") { |stats| stats.increment_count(dropped_count) }
      end
    end
  end
end
