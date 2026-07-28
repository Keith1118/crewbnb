require "test_helper"

# The charge job must be able to catch up. If a daily run is missed — a deploy,
# a cron outage, a booking confirmed after its own charge date — the stays it
# skipped have to be picked up next time, including ones whose check-in has
# already gone by.
class ChargeCatchupTest < ActiveSupport::TestCase
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified, stripe_customer_id: "cus_1")

    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  # check_in_not_in_past only guards creation — a stay booked legitimately and
  # then left behind by a missed job run has a past check-in. Create it in the
  # future, then move the dates back, which is the state the job actually meets.
  def booking_checking_in(days)
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                               stripe_payment_method_id: "pm_1",
                               check_in: Date.current + 20, check_out: Date.current + 22)
    return booking if days == 20

    booking.update_columns(check_in: Date.current + days, check_out: Date.current + days + 2)
    booking.reload
  end

  def succeeding_intent = Struct.new(:id, :status).new("pi_ok", "succeeded")

  test "a stay whose check-in has passed is still due a charge" do
    booking = booking_checking_in(-3)

    assert booking.charge_due?,
           "an unpaid confirmed stay past check-in is still owed"
  end

  test "the job charges a stay whose check-in was missed" do
    missed = booking_checking_in(-3)

    stub_class_method(Stripe::PaymentIntent, :create, succeeding_intent) do
      ChargeDueBookingsJob.perform_now
    end

    assert missed.reload.paid?,
           "a missed stay must be caught up on the next run, not stranded unpaid"
    assert_equal missed.total_price, missed.amount_paid
  end

  test "the job still charges stays inside the lead time and leaves later ones alone" do
    due   = booking_checking_in(Booking::CHARGE_LEAD_TIME.in_days.to_i - 1)
    later = booking_checking_in(40)

    stub_class_method(Stripe::PaymentIntent, :create, succeeding_intent) do
      ChargeDueBookingsJob.perform_now
    end

    assert due.reload.paid?
    assert_not later.reload.paid?
  end

  test "an already-paid past stay is not charged twice" do
    booking = booking_checking_in(-3)

    stub_class_method(Stripe::PaymentIntent, :create, succeeding_intent) do
      ChargeDueBookingsJob.perform_now
      ChargeDueBookingsJob.perform_now
    end

    assert_equal 1, booking.reload.payments.succeeded.count,
                 "re-running the job must not double-charge"
  end
end
