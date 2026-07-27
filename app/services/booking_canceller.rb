# Cancels a booking and refunds whatever the policy says is owed.
#
# Until now refunds were manual because nothing in the schema said how much to
# give back. With one platform-wide free-cancellation window and a two-option
# host policy for what happens after it, the amount is computable — so it
# happens automatically rather than waiting on someone remembering.
#
#   - Guest cancels inside the free window  → full refund
#   - Guest cancels after it                → the listing's policy (nothing, or 50%)
#   - Host or admin cancels                 → full refund, always. The guest did
#     nothing wrong and shouldn't be out of pocket for the host's change of mind.
class BookingCanceller
  Result = Struct.new(:ok?, :refunded, :error)

  def self.call(booking, by:) = new(booking, by).call

  def initialize(booking, by)
    @booking = booking
    @by = by
  end

  def call
    refund = refund_amount
    @booking.cancelled!
    BookingMailer.cancellation(@booking).deliver_later

    return Result.new(true, 0, nil) unless refund.positive?

    issue_refund(refund)
  end

  private

  def host_cancelled?
    @by == :host
  end

  def refund_amount
    return 0 unless @booking.paid?

    host_cancelled? ? @booking.amount_paid : @booking.refund_on_cancellation
  end

  def issue_refund(amount)
    payment = @booking.payments.succeeded.order(created_at: :desc).first
    result = PaymentRefunder.call(payment, amount: amount)

    if result.ok?
      Result.new(true, amount, nil)
    else
      # The cancellation stands either way — the dates must go back on sale. The
      # refund is chased by hand from the admin booking page.
      Rails.logger.error("BookingCanceller: booking #{@booking.id} cancelled but refund failed — #{result.error}")
      Result.new(true, 0, result.error)
    end
  end
end
