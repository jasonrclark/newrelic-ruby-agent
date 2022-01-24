# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.

require 'new_relic/agent/event_buffer'

module NewRelic
  module Agent
    class LogEventBuffer < EventBuffer
      def append_event(event)
        unless full?
          @items << event
        end
      end

      def decrement_lifetime_counts_by n
      end
    end
  end
end
