# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'multiverse_helpers'

# These tests are designed to work in conjunction with a local newrelic.yml
# file set with "insecure" settings and the server returning "insecure" values,
# and confirm that high security changes the actual agent behavior, not just
# the settings in question.
class HighSecurityTest < Minitest::Test

  include MultiverseHelpers

  setup_and_teardown_agent do |collector|
    # Because our tests will default to using SSL, we need to stub that out
    # on our HTTP connects to the fake collector which doesn't have SSL...
    Net::HTTPSession.any_instance.expects('use_ssl=').with(true).at_least_once

    collector.stub('connect', {
      "agent_run_id" => 1,
      "listen_to_server_config" => true,

      "agent_config" => {
        "capture_params" => true,
      }
    }, 200)
  end

  def test_connects_via_ssl_no_matter_what
    # Expectation is set in setup since we all need to sidestep the use_ssl=
    # setting, and mocking gets weird if we call `stubs` then try to `expects`
    NewRelic::Agent.manual_start(:ssl => false)
  end

  def test_sends_high_security_flag_in_connect
    data = $collector.calls_for('connect')
    assert stringify_keys(data.first.body)["high_security"]
  end

  def test_disallows_server_config_from_overriding_high_security
    refute NewRelic::Agent.config[:capture_params]
  end

  def test_doesnt_capture_params
    in_transaction(:filtered_params => { "loose" => "params" }) do
      # no-op
    end
    assert_empty last_transaction_trace_request_params
  end

  def test_doesnt_record_custom_parameters
    in_transaction do
      NewRelic::Agent.add_custom_parameters(:not => "allowed")
    end

    assert_nil last_transaction_trace.params[:custom_params][:not]
    refute_nil last_transaction_trace.params[:custom_params][:cpu_time]
    refute_nil last_transaction_trace.params[:custom_params][:'nr.trip_id']
    refute_nil last_transaction_trace.params[:custom_params][:'nr.path_hash']
  end

end
