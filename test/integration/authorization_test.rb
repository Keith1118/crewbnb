require "test_helper"

# The walls between the three areas. A guest must never reach host or admin
# tools; a host must never reach admin tools.
class AuthorizationTest < ActionDispatch::IntegrationTest
  HOST_PATHS  = %w[host_root_path host_properties_path host_bookings_path host_calendar_path].freeze
  ADMIN_PATHS = %w[admin_root_path admin_users_path admin_properties_path admin_bookings_path].freeze

  test "a signed-out visitor is sent to sign in for host and admin areas" do
    (HOST_PATHS + ADMIN_PATHS).each do |helper|
      get send(helper)
      assert_redirected_to new_user_session_path, "#{helper} should require sign-in"
    end
  end

  test "a guest is kept out of the host area" do
    sign_in create(:user)

    HOST_PATHS.each do |helper|
      get send(helper)
      assert_redirected_to root_path, "#{helper} should be off-limits to guests"
    end
  end

  test "a host is kept out of the admin area" do
    sign_in create(:user, :host)

    ADMIN_PATHS.each do |helper|
      get send(helper)
      assert_not_equal 200, response.status, "#{helper} should not render for a host"
    end
  end

  test "an admin can reach the admin area" do
    sign_in create(:user, :admin)

    get admin_root_path

    assert_response :success
  end

  test "a guest cannot view another guest's booking" do
    others_booking = create(:booking, user: create(:user))
    sign_in create(:user)

    get booking_path(others_booking)

    assert_redirected_to root_path # Pundit denial redirects back to root
  end

  test "a guest cannot view another guest's invoice" do
    others_booking = create(:booking, user: create(:user))
    sign_in create(:user)

    get invoice_booking_path(others_booking)

    assert_redirected_to bookings_path
  end
end
