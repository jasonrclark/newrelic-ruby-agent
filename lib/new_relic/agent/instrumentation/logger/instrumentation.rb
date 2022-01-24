# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.

module NewRelic
  module Agent
    module Instrumentation
      module Logger
        def skip_instrumenting?
          defined?(@skip_instrumenting) && @skip_instrumenting
        end

        def mark_skip_instrumenting
          @skip_instrumenting = true
        end

        def clear_skip_instrumenting
          @skip_instrumenting = false
        end

        def format_message_with_tracing(severity, datetime, progname, msg)
          formatted_message = yield
          return formatted_message if skip_instrumenting?

          begin
            # It's critical we don't instrument logging from metric recording
            # methods within NewRelic::Agent, or we'll stack overflow!!
            mark_skip_instrumenting

            unless ::NewRelic::Agent.agent.nil?
              ::NewRelic::Agent.agent.log_event_aggregator.record(formatted_message, severity)
            end

            return formatted_message
          ensure
            clear_skip_instrumenting
          end
        end
      end
    end
  end
end
