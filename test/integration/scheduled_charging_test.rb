require "test_helper"

# The scheduled-charge model: a card is saved at booking, charged
# CHARGE_LEAD_TIME before check-in, and the stay is released if that charge
# fails and the guest never pays by hand.
class ScheduledChargingTest < ActiveSupport::TestCase
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified, stripe_customer_id: "cus_1")

    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  def booking_checking_in(days, status: :confirmed)
    create(:booking, property: @property, user: @guest, status: status,
           stripe_payment_method_id: "pm_1",
           check_in: Date.current + days, check_out: Date.current + days + 2)
  end

  def succeeding_intent = Struct.new(:id, :status).new("pi_ok", "succeeded")

  # ----- when the money moves ----------------------------------------------

  test "the charge date is CHARGE_LEAD_TIME before check-in" do
    booking = booking_checking_in(30)

    assert_equal booking.check_in - Booking::CHARGE_LEAD_TIME, booking.charge_on
    assert_not booking.charge_due?
  end

  test "a stay booked inside the lead time is charged straight away" do
    booking = booking_checking_in(3)

    assert_equal Date.current, booking.charge_on
    assert booking.charge_due?
  end

  test "the job charges stays that have reached their charge date" do
    due = booking_checking_in(Booking::CHARGE_LEAD_TIME.in_days.to_i - 1)
    early = booking_checking_in(40)

    stub_class_method(Stripe::PaymentIntent, :create, ->(*) { succeeding_intent }) do
      ChargeDueBookingsJob.perform_now
    end

    assert due.reload.paid?
    assert_not early.reload.paid?
  end

  test "the job leaves unapproved requests alone" do
    pending = booking_checking_in(2, status: :pending)
    charged = false

    stub_class_method(Stripe::PaymentIntent, :create, ->(*) { charged = true; succeeding_intent }) do
      ChargeDueBookingsJob.perform_now
    end

    assert_not charged, "a stay the host hasn't approved must never be charged"
    assert_not pending.reload.paid?
  end

  test "re-running the job never double-charges" do
    booking = booking_checking_in(2)
    calls = 0

    stub_class_method(Stripe::PaymentIntent, :create, ->(*) { calls += 1; succeeding_intent }) do
      ChargeDueBookingsJob.perform_now
      ChargeDueBookingsJob.perform_now
    end

    assert_equal 1, calls
    assert_equal 1, booking.payments.succeeded.count
  end

  test "one declined card doesn't stop the rest of the run" do
    doomed = booking_checking_in(2)
    # A second property, so the two stays don't clash on dates.
    fine = create(:booking, property: create(:property, user: @host), user: @guest,
                  status: :confirmed, stripe_payment_method_id: "pm_1",
                  check_in: Date.current + 2, check_out: Date.current + 4)
    seen = 0

    stub_class_method(Stripe::PaymentIntent, :create, ->(*) {
      seen += 1
      raise Stripe::CardError.new("declined", nil) if seen == 1

      succeeding_intent
    }) do
      ChargeDueBookingsJob.perform_now
    end

    assert_equal 2, seen, "the second booking must still be attempted"
    assert [ doomed.reload, fine.reload ].one?(&:paid?)
  end

  # ----- releasing stays nobody paid for ------------------------------------

  test "an expired grace period releases the dates" do
    booking = booking_checking_in(5)
    booking.update!(status: :awaiting_payment, payment_due_by: 1.hour.ago)

    ReleaseUnpaidBookingsJob.perform_now

    assert booking.reload.cancelled?
  end

  test "a guest still inside the grace period keeps their stay" do
    booking = booking_checking_in(5)
    booking.update!(status: :awaiting_payment, payment_due_by: 12.hours.from_now)

    ReleaseUnpaidBookingsJob.perform_now

    assert booking.reload.awaiting_payment?
  end

  test "a guest who paid by hand isn't cancelled by the sweep" do
    booking = booking_checking_in(5)
    booking.update!(status: :awaiting_payment, payment_due_by: 1.hour.ago)
    create(:payment, booking: booking, status: :succeeded, amount: booking.total_price)

    ReleaseUnpaidBookingsJob.perform_now

    assert_not booking.reload.cancelled?
  end
end
