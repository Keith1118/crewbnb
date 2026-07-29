require "test_helper"

# The health endpoint decides whether Render keeps sending traffic to an
# instance, so it has to actually fail when the app can't serve.
class HealthCheckTest < ActionDispatch::IntegrationTest
  test "reports healthy when the database answers" do
    get rails_health_check_path

    assert_response :success
    assert_equal "ok", response.body
  end

  test "reports unhealthy when the database cannot be reached" do
    # The exact failure that took the site down: the app is up, the database
    # refuses it. rails/health#show returned 200 straight through this.
    broken = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "role not permitted to log in" }

    stub_class_method(ActiveRecord::Base, :connection, broken) do
      get rails_health_check_path
    end

    assert_response :service_unavailable,
                    "a database the app can't reach must fail the health check"
    assert_match(/database unavailable/i, response.body)
  end

  test "survives an unexpected error rather than raising out of the check" do
    exploding = ->(*) { raise "something nobody predicted" }

    stub_class_method(ActiveRecord::Base, :connection, exploding) do
      get rails_health_check_path
    end

    assert_response :service_unavailable
  end

  test "needs no session, CSRF token or browser-shaped user agent" do
    # Render's checker is not a browser, and ApplicationController's
    # allow_browser rule must not be able to reject it.
    get rails_health_check_path, headers: { "User-Agent" => "Render/1.0 health-check" }

    assert_response :success
  end
end
