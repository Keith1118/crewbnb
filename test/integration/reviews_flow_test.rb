require "test_helper"

# Reviews can only be written by a guest who actually completed a stay.
class ReviewsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @property = create(:property)
    sign_in(@guest = create(:user, :business_verified))
  end

  # A genuinely-finished stay: created valid, then backdated past the
  # check_in_not_in_past guard (which only runs on create).
  def completed_booking(guest: @guest)
    booking = create(:booking, property: @property, user: guest,
                               check_in: Date.current + 7, check_out: Date.current + 10)
    booking.update_columns(status: Booking.statuses[:completed],
                           check_in: Date.current - 10, check_out: Date.current - 7)
    booking
  end

  test "a guest who completed a stay can leave a review" do
    booking = completed_booking

    assert_difference "Review.count", 1 do
      post booking_reviews_path(booking), params: { review: { rating: 5, comment: "Great stay." } }
    end
  end

  test "a guest with no completed stay is turned away" do
    # A pending booking is not a completed stay.
    create(:booking, property: @property, user: @guest, status: :pending)

    assert_no_difference "Review.count" do
      post property_reviews_path(@property), params: { review: { rating: 5, comment: "Nope." } }
    end
  end

  test "an empty review is re-rendered, not saved" do
    booking = completed_booking

    assert_no_difference "Review.count" do
      post booking_reviews_path(booking), params: { review: { rating: nil, comment: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "a guest cannot review another guest's booking" do
    others_booking = completed_booking(guest: create(:user))

    assert_no_difference "Review.count" do
      post booking_reviews_path(others_booking), params: { review: { rating: 5, comment: "Not mine." } }
    end

    assert_response :not_found
  end
end
