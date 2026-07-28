require "test_helper"

# amount_paid drives refunds and host payouts, so it has to stay correct across
# every refund shape — including a full refund, which moves the payment's status
# out of :succeeded.
class RefundAccountingTest < ActiveSupport::TestCase
  setup do
    host = create(:user, :stripe_ready)
    property = create(:property, user: host, price_per_night: 100)
    @booking = create(:booking, property: property, user: create(:user, :business_verified),
                                status: :confirmed,
                                check_in: Date.current + 20, check_out: Date.current + 22)
    @payment = @booking.payments.create!(amount: 200, currency: "EUR", status: :succeeded,
                                         stripe_payment_intent_id: "pi_1")
  end

  test "an unrefunded payment counts in full" do
    assert_equal 200, @booking.amount_paid
    assert @booking.paid?
  end

  test "a partial refund leaves the remainder" do
    @payment.update!(refunded_amount: 50)

    assert_equal 150, @booking.amount_paid
  end

  test "a full refund leaves nothing paid, not a negative balance" do
    # This is what PaymentRefunder does once refunded_amount reaches the total.
    @payment.update!(refunded_amount: 200, status: :refunded)

    assert_equal 0, @booking.amount_paid,
                 "a fully refunded payment must read as zero, never negative"
    assert_not @booking.paid?
  end

  test "a full refund owes the host nothing" do
    @payment.update!(refunded_amount: 200, status: :refunded)

    assert_equal 0, @booking.host_payout_due
  end

  test "a partial refund shrinks the host payout proportionally" do
    @payment.update!(refunded_amount: 100)

    # EUR100 left, less 7.5% commission.
    assert_equal 92.5, @booking.host_payout_due
  end
end
