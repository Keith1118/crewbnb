require "test_helper"

# Cancellation refunds. One platform-wide free window, then whatever the
# listing's policy promises — and a host cancelling always refunds in full,
# because the guest did nothing wrong.
class CancellationRefundsTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host, cancellation_policy: :strict)
    @guest = create(:user, :business_verified)

    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  # `days` until check-in decides which side of the free window we're on.
  def paid_booking(days, amount: 400)
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                     check_in: Date.current + days, check_out: Date.current + days + 2)
    create(:payment, booking: booking, status: :succeeded, amount: amount,
           stripe_payment_intent_id: "pi_1")
    booking
  end

  def stub_refund(&block)
    @captured = nil
    stub_class_method(Stripe::Refund, :create, ->(args) { @captured = args; Struct.new(:id).new("re_1") }, &block)
  end

  def cancel_as(user, booking, path)
    sign_in user
    stub_refund { patch path, params: { booking: { status: "cancelled" } } }
  end

  test "cancelling inside the free window refunds in full" do
    booking = paid_booking(30)

    cancel_as @guest, booking, booking_path(booking)

    assert booking.reload.cancelled?
    assert_equal 40_000, @captured[:amount]
  end

  test "a strict listing refunds nothing after the free window" do
    booking = paid_booking(2)

    cancel_as @guest, booking, booking_path(booking)

    assert booking.reload.cancelled?
    assert_nil @captured, "no refund should have been attempted"
  end

  test "a partial listing refunds half after the free window" do
    @property.update!(cancellation_policy: :partial)
    booking = paid_booking(2)

    cancel_as @guest, booking, booking_path(booking)

    assert_equal 20_000, @captured[:amount]
  end

  test "the free window ends FREE_CANCELLATION_WINDOW before check-in" do
    inside = paid_booking(Booking::FREE_CANCELLATION_WINDOW.in_days.to_i + 1)
    assert inside.free_cancellation?

    outside = create(:booking, property: create(:property, user: @host), user: @guest,
                     status: :confirmed, check_in: Date.current + 3, check_out: Date.current + 5)
    assert_not outside.free_cancellation?
  end

  test "a host cancelling refunds in full even after the window" do
    booking = paid_booking(2)

    cancel_as @host, booking, host_booking_path(booking)

    assert booking.reload.cancelled?
    assert_equal 40_000, @captured[:amount], "the guest shouldn't lose out on the host's change of mind"
  end

  test "an unpaid booking cancels cleanly with no refund" do
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                     check_in: Date.current + 30, check_out: Date.current + 32)

    cancel_as @guest, booking, booking_path(booking)

    assert booking.reload.cancelled?
    assert_nil @captured
  end

  test "a failed refund still cancels, so the dates go back on sale" do
    booking = paid_booking(30)
    sign_in @guest

    stub_class_method(Stripe::Refund, :create, ->(*) { raise Stripe::StripeError.new("already refunded") }) do
      patch booking_path(booking), params: { booking: { status: "cancelled" } }
    end

    assert booking.reload.cancelled?
  end

  # The host isn't paid until the day after check-in, so a cancellation before
  # then is refunded straight out of Crewbase's balance with nothing to reverse.
  test "a refund before the host is paid touches only our own balance" do
    booking = paid_booking(30)
    reversed = false

    sign_in @guest
    stub_class_method(Stripe::Transfer, :create_reversal, ->(*) { reversed = true }) do
      stub_refund { patch booking_path(booking), params: { booking: { status: "cancelled" } } }
    end

    assert_equal 40_000, @captured[:amount]
    assert_not reversed, "nothing has left our balance yet, so nothing to claw back"
  end

  test "a refund after the host is paid claws back their share" do
    booking = paid_booking(30)
    booking.update!(host_transfer_id: "tr_1", host_paid_at: Time.current)
    reversal = nil

    sign_in @guest
    stub_class_method(Stripe::Transfer, :create_reversal, ->(id, args) { reversal = [ id, args ] }) do
      stub_refund { patch booking_path(booking), params: { booking: { status: "cancelled" } } }
    end

    assert_equal "tr_1", reversal.first
    # 92.5% of the €400 refunded — the host's share, leaving our commission.
    assert_equal 37_000, reversal.last[:amount]
  end
end
