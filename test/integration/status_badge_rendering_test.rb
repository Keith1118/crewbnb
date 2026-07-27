require "test_helper"

# Every screen that shows a booking's status must survive every status a booking
# can hold. Adding awaiting_payment left five copy-pasted `case` statements
# returning nil, and the host dashboard died on `undefined method [] for nil` —
# for the host, at sign-in, with no way past it.
class StatusBadgeRenderingTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :host)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified)
    @admin = create(:user, :admin)
  end

  def booking_with(status)
    create(:booking, property: @property, user: @guest, status: status,
           check_in: Date.current + 10, check_out: Date.current + 12)
  end

  # Drive every status through every screen rather than trusting that the one
  # that broke was the only one that could.
  Booking.statuses.each_key do |status|
    test "the host dashboard renders a #{status} booking" do
      booking_with(status)
      sign_in @host

      get host_root_path

      assert_response :success
    end

    test "the host booking list renders a #{status} booking" do
      booking_with(status)
      sign_in @host

      get host_bookings_path

      assert_response :success
    end

    test "the admin booking list renders a #{status} booking" do
      booking_with(status)
      sign_in @admin

      get admin_bookings_path

      assert_response :success
    end

    test "the admin dashboard renders a #{status} booking" do
      booking_with(status)
      sign_in @admin

      get admin_root_path

      assert_response :success
    end

    test "the admin user page renders a #{status} booking" do
      booking_with(status)
      sign_in @admin

      get admin_user_path(@guest)

      assert_response :success
    end

    test "the guest booking list renders a #{status} booking" do
      booking_with(status)
      sign_in @guest

      get bookings_path

      assert_response :success
    end
  end

  test "an unrecognised status still produces a badge rather than nil" do
    helper = Class.new { include BookingsHelper }.new

    assert_not_nil helper.booking_status_badge_classes("something_new")
    assert_equal "Something new", helper.booking_status_label("something_new")
  end
end
