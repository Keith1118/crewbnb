require "test_helper"

# What happens when a verified guest actually places a booking, with bookings
# open. Covers the request-to-book path (no Stripe) and the guards around it.
class BookingCreationTest < ActionDispatch::IntegrationTest
  setup do
    @property = create(:property, instant_book: false)
    sign_in(@guest = create(:user, :business_verified))
  end

  def book(overrides = {})
    params = { check_in: Date.current + 7, check_out: Date.current + 10, guests_count: 2 }.merge(overrides)
    post property_bookings_path(@property), params: { booking: params }
  end

  def with_bookings_open
    previous = ENV["BOOKINGS_OPEN"]
    ENV["BOOKINGS_OPEN"] = "true"
    yield
  ensure
    ENV["BOOKINGS_OPEN"] = previous
  end

  test "a request-to-book listing creates a pending booking and emails the host" do
    with_bookings_open do
      assert_difference "Booking.count", 1 do
        perform_enqueued_jobs { book }
      end
    end

    booking = @guest.bookings.last
    assert booking.pending?
    assert_equal (Date.current + 7), booking.check_in
    # The host is told about the request (the "new booking" mail goes to them).
    assert ActionMailer::Base.deliveries.any? { |m| m.to.include?(@property.user.email) },
           "expected the host to be emailed about the new request"
  end

  test "a booking that overlaps an existing one is rejected" do
    create(:booking, :confirmed, property: @property,
                                 check_in: Date.current + 7, check_out: Date.current + 10)

    with_bookings_open do
      assert_no_difference "Booking.count" do
        book(check_in: Date.current + 8, check_out: Date.current + 11)
      end
    end

    assert_response :unprocessable_entity
  end

  test "a party larger than the listing is rejected" do
    with_bookings_open do
      assert_no_difference "Booking.count" do
        book(guests_count: @property.max_guests + 1)
      end
    end

    assert_response :unprocessable_entity
  end

  test "the total price is computed server-side, not taken from the guest" do
    with_bookings_open do
      book(check_in: Date.current + 7, check_out: Date.current + 10) # 3 nights
    end

    assert_equal @property.price_per_night * 3, @guest.bookings.last.total_price
  end
end
