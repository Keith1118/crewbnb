# Refunds a Connect destination charge.
#
# Deliberately admin-triggered rather than automatic: Crewbase has no
# cancellation policy field, so there is no rule that says how much of a
# cancelled stay to give back. A human decides the amount; this just executes it
# correctly and keeps our records in step with Stripe.
#
# Both reversal flags matter. The guest's money went to the host's connected
# account and our commission was taken as an application fee, so a refund that
# didn't reverse them would come out of Crewbase's own balance — we'd be paying
# the guest back with our money while the host kept theirs. Stripe prorates both
# reversals for partial refunds.
class PaymentRefunder
  Result = Struct.new(:ok?, :error, :amount)

  def self.call(payment, amount: nil) = new(payment, amount).call

  def initialize(payment, amount)
    @payment = payment
    @amount = amount
  end

  def call
    return failure("Only a succeeded payment can be refunded.") unless @payment.succeeded?
    return failure("No Stripe payment is linked to this record.") if @payment.stripe_payment_intent_id.blank?

    amount = (@amount || refundable).to_d.round(2)
    return failure("Refund amount must be more than zero.") unless amount.positive?
    return failure("That's more than the #{format_eur(refundable)} still refundable.") if amount > refundable

    refund(amount)
  rescue Stripe::StripeError => e
    failure(e.message)
  end

  private

  def refundable
    @payment.amount - (@payment.refunded_amount || 0)
  end

  def refund(amount)
    Stripe::Refund.create(
      payment_intent: @payment.stripe_payment_intent_id,
      amount: (amount * 100).to_i,
      refund_application_fee: true,
      reverse_transfer: true
    )

    total = (@payment.refunded_amount || 0) + amount
    @payment.update!(
      refunded_amount: total,
      status: total >= @payment.amount ? :refunded : @payment.status
    )
    Result.new(true, nil, amount)
  end

  def failure(message) = Result.new(false, message, nil)

  def format_eur(value) = "€#{ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2)}"
end
