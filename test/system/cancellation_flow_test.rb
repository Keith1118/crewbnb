require "application_system_test_case"

# Cancelling from the guest's own booking page, on both sides of the free
# cancellation window, with the refund actually asserted.
class CancellationFlowTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :stripe_ready)
    @guest = create(:user, :business_verified, stripe_customer_id: "cus_1")
    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  # A confirmed, fully-paid stay checking in `days` from now.
  def paid_booking(days:, policy: :partial)
    property = create(:property, user: @host, price_per_night: 100,
                                 cancellation_policy: policy)
    booking = create(:booking, property: property, user: @guest, status: :confirmed,
                               stripe_payment_method_id: "pm_1",
                               check_in: Date.current + days,
                               check_out: Date.current + days + 2)
    booking.payments.create!(amount: booking.total_price, currency: "EUR",
                             status: :succeeded, stripe_payment_intent_id: "pi_1")
    booking
  end

  def stub_refund(&block)
    refund = Struct.new(:id, :status, :amount).new("re_1", "succeeded", 0)
    stub_class_method(Stripe::Refund, :create, refund, &block)
  end

  test "cancelling inside the free window refunds the guest in full" do
    booking = paid_booking(days: 30) # free window runs until 7 days before
    assert booking.free_cancellation?

    sign_in_as(@guest)
    visit booking_path(booking)

    stub_refund do
      submit_form_button("Cancel Booking", expect: /cancelled/i, confirm: true)
    end

    booking.reload
    assert booking.cancelled?
    assert_text "€200.00 has been refunded", exact: false
    assert_equal 0, booking.amount_paid, "a full refund leaves nothing paid"
  end

  test "cancelling after the free window refunds only what the listing promises" do
    booking = paid_booking(days: 3, policy: :partial) # inside 7 days
    assert_not booking.free_cancellation?
    assert_equal 100, booking.refund_on_cancellation, "partial policy refunds 50% of EUR200"

    sign_in_as(@guest)
    visit booking_path(booking)

    stub_refund do
      submit_form_button("Cancel Booking", expect: /cancelled/i, confirm: true)
    end

    booking.reload
    assert booking.cancelled?
    assert_equal 100, booking.amount_paid, "half of EUR200 stays with the platform"
  end

  test "a strict listing refunds nothing after the free window" do
    booking = paid_booking(days: 3, policy: :strict)
    assert_equal 0, booking.refund_on_cancellation

    sign_in_as(@guest)
    visit booking_path(booking)
    submit_form_button("Cancel Booking", expect: /cancelled/i, confirm: true)

    booking.reload
    assert booking.cancelled?
    assert_text(/no refund is due/i)
    assert_equal 200, booking.amount_paid
  end

  test "cancelled dates go back on sale" do
    booking = paid_booking(days: 30)
    property = booking.property

    assert_not property.available_between?(booking.check_in, booking.check_out)

    sign_in_as(@guest)
    visit booking_path(booking)
    stub_refund { submit_form_button("Cancel Booking", expect: /cancelled/i, confirm: true) }

    assert property.reload.available_between?(booking.check_in, booking.check_out),
           "cancelling must free the dates for someone else"
  end
end
