# Refunds a Connect destination charge.
#
# Deliberately admin-triggered rather than automatic: Crewbase has no
# cancellation policy field, so there is no rule that says how much of a
# cancelled stay to give back. A human decides the amount; this just executes it
# correctly and keeps our records in step with Stripe.
#
# Where the money is decides how much work this is. Guests are charged at T-10
# but hosts aren't paid until the day after check-in, so most refunds happen
# while the whole amount is still in Crewbase's balance — a plain refund, with
# nothing to reverse.
#
# Once HostPayoutsJob has paid the host, their share has left. Refunding then
# without reversing the transfer would mean giving the guest their money back
# out of Crewbase's own pocket while the host kept theirs, so the host's
# proportion is pulled back first.
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
    reverse_host_transfer(amount)

    Stripe::Refund.create(
      payment_intent: @payment.stripe_payment_intent_id,
      amount: (amount * 100).to_i
    )

    total = (@payment.refunded_amount || 0) + amount
    @payment.update!(
      refunded_amount: total,
      status: total >= @payment.amount ? :refunded : @payment.status
    )
    Result.new(true, nil, amount)
  end

  # Claw back the host's proportion of what we're giving the guest — but only if
  # they've actually been paid. Before check-in the money is still ours and
  # there is nothing to reverse.
  def reverse_host_transfer(amount)
    booking = @payment.booking
    return unless booking.host_paid?

    host_share = (amount * (1 - Booking::COMMISSION_RATE)).round(2)
    return unless host_share.positive?

    Stripe::Transfer.create_reversal(
      booking.host_transfer_id,
      amount: (host_share * 100).to_i
    )
  end

  def failure(message) = Result.new(false, message, nil)

  def format_eur(value) = "€#{ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2)}"
end
