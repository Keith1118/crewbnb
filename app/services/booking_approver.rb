# What happens when a host approves a request-to-book stay.
#
# Until now approval confirmed the booking outright, which meant a guest on a
# request-to-book listing was never charged — the stay was blocked out and the
# host was owed money with nothing collected. When the guest can be charged
# online we now hold the booking in awaiting_payment and ask them for a card;
# PaymentsController confirms it once the payment succeeds.
#
# Where online payment isn't possible (Stripe unconfigured, or the host hasn't
# finished payout onboarding) the old behaviour is still correct: the stay is
# settled off-platform, so approval confirms it.
class BookingApprover
  def self.call(booking) = new(booking).call

  def initialize(booking)
    @booking = booking
  end

  # Returns :payment_requested or :confirmed so callers can word their flash.
  def call
    @booking.payable_online? ? request_payment : confirm
  end

  private

  def request_payment
    @booking.awaiting_payment!
    BookingMailer.payment_requested(@booking).deliver_later
    AutoMessenger.payment_requested(@booking)
    :payment_requested
  end

  def confirm
    @booking.confirmed!
    AutoMessenger.booking_confirmed(@booking)
    :confirmed
  end
end
