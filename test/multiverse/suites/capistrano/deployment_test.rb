# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.

require 'fake_rpm_site'
require 'new_relic/cli/command'

class DeploymentTest < Minitest::Test
  def setup
    @rpm_site ||= NewRelic::FakeRpmSite.new
    @rpm_site.reset
    @rpm_site.run
  end

  def test_deploys_to_configured_application
    cap_it
    assert_deployment_value("application_id", "test")
  end

  def test_deploys_with_commandline_parameter
    # Capistrano 3 doesn't provide built-in commandline params -> settings
    # We wire our own up via ENV to test setting out setting custom values
    env = {
      'NEWRELIC_CAPISTRANO_USER' => "Optimus Prime",
      'NEWRELIC_CAPISTRANO_APPNAME' => "Tesseract",
      'NEWRELIC_CAPISTRANO_REVISION' => "C-001",
      'NEWRELIC_CAPISTRANO_CHANGELOG' => "The greatest weakness of most humans is their hesitancy to tell others they love them while they're alive."
    }

    cap_it(env)

    assert_deployment_value("user", "Optimus Prime")
    assert_deployment_value("application_id", "Tesseract")
    assert_deployment_value("revision", "C-001")
    assert_deployment_value("changelog", "The greatest weakness of most humans is their hesitancy to tell others they love them while they're alive.")
  end

  def assert_deployment_value(key, value)
    assert_equal(1, @rpm_site.requests.count)
    assert_equal(value, @rpm_site.requests.first["deployment"][key])
  end

  def cap_it(custom_env = {})
    cmd = "cap production newrelic:notice_deployment"
    default_env = {'FAKE_RPM_SITE_PORT' => @rpm_site.port.to_s}
    output = with_environment(default_env.merge(custom_env)) do
      `#{cmd}`
    end
    assert $?.success?, "cap command '#{cmd}' failed with output: #{output}"
  end
end
