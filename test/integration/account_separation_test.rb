require "test_helper"

# Guest and host accounts are separate entities. A host account manages
# listings; it doesn't browse, book, or pay. There's no switching between the
# two — an account is one thing for its whole life.
class AccountSeparationTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified)
  end

  test "a host can't reach the guest bookings area" do
    sign_in @host

    get bookings_path

    assert_redirected_to host_root_path
  end

  test "a host can't open the booking form" do
    sign_in @host

    get new_property_booking_path(@property)

    assert_redirected_to host_root_path
  end

  test "a host can't place a booking" do
    sign_in @host

    assert_no_difference -> { Booking.count } do
      post property_bookings_path(@property), params: {
        booking: { check_in: Date.current + 20, check_out: Date.current + 23, guests_count: 1 }
      }
    end
  end

  test "a host can't reach business verification" do
    sign_in @host

    get new_business_verification_path

    assert_redirected_to host_root_path
  end

  test "a guest keeps full access to their own side" do
    sign_in @guest

    get bookings_path

    assert_response :success
  end

  test "a guest still can't reach the host area" do
    sign_in @guest

    get host_root_path

    assert_redirected_to root_path
  end

  # Admins keep both sides so they can act for a guest during support.
  test "an admin may still use the guest side" do
    sign_in create(:user, :admin)

    get bookings_path

    assert_response :success
  end

  test "the host nav offers no way back to the guest site" do
    sign_in @host

    get host_root_path

    assert_response :success
    assert_select "a[href=?]", root_path, count: 0
  end

  test "a role can't be changed after signup" do
    sign_in @guest

    patch user_registration_path, params: {
      user: { role: "host", current_password: @guest.password }
    }

    assert @guest.reload.guest?, "a guest must not be able to promote themselves to host"
  end
end
