require "test_helper"

# Stripe Connect destination charges: the guest pays the listed total, Crewbase
# keeps its commission as the application fee, and the rest goes to the host's
# connected account. Payment is only ever offered when the host can receive it.
class ConnectPaymentsTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host, instant_book: true)
    sign_in(@guest = create(:user, :business_verified))
    @booking = create(:booking, property: @property, user: @guest, status: :pending,
                      check_in: Date.current + 7, check_out: Date.current + 10)

    @orig_key = Stripe.api_key
    @orig_pub = ENV["STRIPE_PUBLISHABLE_KEY"]
    Stripe.api_key = "sk_test_x"
    ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_x"
  end

  teardown do
    Stripe.api_key = @orig_key
    @orig_pub.nil? ? ENV.delete("STRIPE_PUBLISHABLE_KEY") : ENV["STRIPE_PUBLISHABLE_KEY"] = @orig_pub
  end

  def fake_intent
    Struct.new(:id, :client_secret, :status, :amount)
          .new("pi_123", "pi_123_secret", "requires_payment_method", 0)
  end

  def with_bookings_open
    previous = ENV["BOOKINGS_OPEN"]
    ENV["BOOKINGS_OPEN"] = "true"
    yield
  ensure
    ENV["BOOKINGS_OPEN"] = previous
  end

  test "the payment intent routes money to the host with the commission as the app fee" do
    captured = nil
    stub_class_method(Stripe::PaymentIntent, :create, ->(args) { captured = args; fake_intent }) do
      get new_booking_payment_path(@booking)
    end

    assert_response :success
    assert_equal @host.stripe_account_id, captured.dig(:transfer_data, :destination)
    assert_equal (@booking.commission_amount * 100).to_i, captured[:application_fee_amount]
  end

  test "payment falls back to request-to-book when the host isn't payout-ready" do
    @host.update!(stripe_charges_enabled: false)

    get new_booking_payment_path(@booking)

    assert_redirected_to booking_path(@booking)
  end

  # Nobody is charged at booking time any more — the guest saves a card and
  # BookingCharger takes the money nearer check-in.
  test "booking sends the guest to save a card when the host can be paid" do
    with_bookings_open do
      post property_bookings_path(@property), params: {
        booking: { check_in: Date.current + 20, check_out: Date.current + 23, guests_count: 2 }
      }
    end

    assert_redirected_to new_booking_card_path(@guest.bookings.last)
  end

  test "instant-book with an unconnected host routes to request-to-book" do
    @host.update!(stripe_charges_enabled: false)

    with_bookings_open do
      post property_bookings_path(@property), params: {
        booking: { check_in: Date.current + 20, check_out: Date.current + 23, guests_count: 2 }
      }
    end

    assert_redirected_to @guest.bookings.last
  end
end
