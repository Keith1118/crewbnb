# What happens when a host approves a request-to-book stay.
#
# The guest's card is already on file — BookingCardsController took it when they
# booked — so approval doesn't ask them for anything. It confirms the stay and
# leaves ChargeDueBookingsJob to take the money CHARGE_LEAD_TIME before check-in.
#
# The exception is a stay approved inside that window, where the charge date has
# already passed: that's charged on the spot, so a booking made a few days out
# never slips through uncharged.
#
# Where no card was taken (Stripe unconfigured, or the host wasn't payout-ready
# at booking time) approval simply confirms — that stay settles off-platform.
class BookingApprover
  def self.call(booking) = new(booking).call

  def initialize(booking)
    @booking = booking
  end

  # Returns :charged, :charge_failed, or :confirmed so callers can word a flash.
  def call
    @booking.confirmed!
    AutoMessenger.booking_confirmed(@booking)

    return :confirmed unless @booking.charge_due?

    BookingCharger.call(@booking).ok? ? :charged : :charge_failed
  end
end
