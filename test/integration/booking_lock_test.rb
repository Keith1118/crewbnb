require "test_helper"

# The BOOKINGS_OPEN flag is what stands between "browsing" and "taking money",
# and it gets flipped by hand in the Render dashboard. These tests pin down both
# sides of it so the pre-launch lock can't be undone by accident.
class BookingLockTest < ActionDispatch::IntegrationTest
  setup do
    @property = create(:property)
    @guest    = create(:user, :business_verified)
    sign_in @guest
  end

  def with_bookings_open(value)
    previous = ENV["BOOKINGS_OPEN"]
    ENV["BOOKINGS_OPEN"] = value
    yield
  ensure
    ENV["BOOKINGS_OPEN"] = previous
  end

  def booking_attributes
    { check_in: Date.current + 7, check_out: Date.current + 10, guests_count: 2 }
  end

  test "guests can still browse a listing while bookings are closed" do
    with_bookings_open("false") do
      get property_path(@property)

      assert_response :success
    end
  end

  test "the booking form is refused while bookings are closed" do
    with_bookings_open("false") do
      get new_property_booking_path(@property)

      assert_response :redirect
      assert_match(/aren't open just yet/, flash[:alert])
    end
  end

  # The important one: closing the form isn't enough if someone can post
  # straight past it.
  test "posting a booking directly is refused while bookings are closed" do
    with_bookings_open("false") do
      assert_no_difference "Booking.count" do
        post property_bookings_path(@property), params: { booking: booking_attributes }
      end

      assert_response :redirect
      assert_match(/aren't open just yet/, flash[:alert])
    end
  end

  test "bookings default to closed when BOOKINGS_OPEN is unset" do
    with_bookings_open(nil) do
      assert_no_difference "Booking.count" do
        post property_bookings_path(@property), params: { booking: booking_attributes }
      end
    end
  end

  test "a booking goes through once BOOKINGS_OPEN is true" do
    with_bookings_open("true") do
      assert_difference "Booking.count", 1 do
        post property_bookings_path(@property), params: { booking: booking_attributes }
      end
    end
  end

  test "an unverified business is sent to verification, not into the booking" do
    sign_in create(:user) # no business_verified_at

    with_bookings_open("true") do
      assert_no_difference "Booking.count" do
        post property_bookings_path(@property), params: { booking: booking_attributes }
      end

      assert_redirected_to new_business_verification_path
    end
  end
end
