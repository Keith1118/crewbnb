# Charges every confirmed booking that has reached its charge date.
#
# Runs daily. Deliberately forgiving: one card failing must never stop the rest
# of the run. Re-running is harmless — both the scope's charge_due? check and
# BookingCharger itself skip anything already paid.
class ChargeDueBookingsJob < ApplicationJob
  queue_as :default

  def perform
    candidates.find_each do |booking|
      next unless booking.charge_due?

      BookingCharger.call(booking)
    rescue => e
      Rails.logger.error("ChargeDueBookingsJob: booking #{booking.id} raised #{e.class}: #{e.message}")
    end
  end

  private

  # Narrow in SQL, decide in Ruby: charge_due? owns the "already paid?" question
  # so there's one definition of it rather than a query that can drift from it.
  def candidates
    Booking.confirmed
           .where.not(stripe_payment_method_id: nil)
           .where(check_in: Date.current..(Date.current + Booking::CHARGE_LEAD_TIME))
           .includes(:payments, property: :user)
  end
end
