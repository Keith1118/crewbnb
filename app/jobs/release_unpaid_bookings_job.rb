# Releases stays whose guest never paid after an automatic charge failed.
#
# A failed charge gives the guest MANUAL_PAYMENT_GRACE to pay by hand. Once that
# runs out the booking is cancelled and the dates go back on sale — otherwise a
# card that quietly expired would hold a property empty until check-in.
class ReleaseUnpaidBookingsJob < ApplicationJob
  queue_as :default

  def perform
    Booking.awaiting_payment
           .where.not(payment_due_by: nil)
           .where(payment_due_by: ...Time.current)
           .find_each do |booking|
      next if booking.paid?

      booking.cancelled!
      BookingMailer.cancellation(booking).deliver_later
    rescue => e
      Rails.logger.error("ReleaseUnpaidBookingsJob: booking #{booking.id} raised #{e.class}: #{e.message}")
    end
  end
end
