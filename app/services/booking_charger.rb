# Takes the money for a booking using the card the guest saved when they booked.
#
# Nobody pays at the moment of booking. We store the card, then charge it
# CHARGE_LEAD_TIME before check-in (or immediately, for a stay booked inside
# that window). This is an *off-session* charge — the guest isn't at their
# keyboard — which matters in two ways:
#
#   - `off_session: true` tells Stripe to attempt it without the customer, and
#     to apply the saved mandate.
#   - Some cards still refuse: expired, out of funds, or a bank demanding 3-D
#     Secure, which cannot be satisfied without the guest present. That isn't an
#     error on our side and mustn't look like one — the booking moves to
#     awaiting_payment, the guest gets a pay-by-hand link, and they have
#     MANUAL_PAYMENT_GRACE to use it before the stay is released.
#
# Money still moves as a destination charge, exactly as an at-the-till payment
# would: the guest pays the listed total, Crewbase keeps its commission as the
# application fee, the rest settles to the host.
class BookingCharger
  Result = Struct.new(:ok?, :error, :payment)

  def self.call(booking) = new(booking).call

  def initialize(booking)
    @booking = booking
    @property = booking.property
  end

  def call
    return failure("This booking has already been paid.") if @booking.paid?
    return failure("No saved card for this booking.") if @booking.stripe_payment_method_id.blank?
    return failure("The host can't receive payments yet.") unless @property.user.stripe_ready?

    charge
  rescue Stripe::CardError => e
    # An expected refusal, not a fault: hand it back to the guest.
    decline(e.message)
  rescue Stripe::StripeError => e
    decline(e.message)
  end

  private

  def charge
    payment = @booking.payments.create!(
      amount: @booking.total_price, currency: "EUR", status: :pending
    )

    intent = Stripe::PaymentIntent.create(intent_params)
    payment.update!(stripe_payment_intent_id: intent.id)

    if intent.status == "succeeded"
      succeed(payment)
    else
      payment.failed!
      decline("The card needs confirmation from the cardholder.")
    end
  end

  def intent_params
    {
      amount: (@booking.total_price * 100).to_i,
      currency: "eur",
      customer: @booking.user.stripe_customer_id,
      payment_method: @booking.stripe_payment_method_id,
      off_session: true,
      confirm: true,
      metadata: { booking_id: @booking.id, user_id: @booking.user_id },
      application_fee_amount: (@booking.commission_amount * 100).to_i,
      transfer_data: { destination: @property.user.stripe_account_id }
    }
  end

  def succeed(payment)
    payment.succeeded!
    @booking.update!(charge_failed_at: nil, payment_due_by: nil)
    @booking.confirmed! unless @booking.confirmed?
    BookingMailer.payment_taken(@booking).deliver_later
    Result.new(true, nil, payment)
  end

  def decline(message)
    @booking.update!(
      status: :awaiting_payment,
      charge_failed_at: Time.current,
      payment_due_by: Booking::MANUAL_PAYMENT_GRACE.from_now
    )
    BookingMailer.payment_failed(@booking).deliver_later
    Rails.logger.info("BookingCharger: booking #{@booking.id} declined — #{message}")
    Result.new(false, message, nil)
  end

  def failure(message) = Result.new(false, message, nil)
end
