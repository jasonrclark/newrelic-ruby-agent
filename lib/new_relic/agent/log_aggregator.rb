# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.

require 'new_relic/agent/custom_event_aggregator'

module NewRelic
  module Agent
    class LogAggregator < CustomEventAggregator
      named :LogAggregator
      capacity_key :'log_sending.max_samples_stored'
      enabled_key :'log_sending.enabled'
    end
  end
end
