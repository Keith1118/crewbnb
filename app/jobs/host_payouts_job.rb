# Pays hosts their share, the day after the guest checks in.
#
# The guest's money has been sitting in Crewbase's balance since T-10. It waits
# there deliberately: free cancellation runs until T-7, so paying the host
# earlier would mean reversing it out of their account afterwards — and if
# they'd already been paid out to their bank, that leaves them overdrawn through
# no fault of their own.
#
# A day after check-in the stay is a fact. Nothing can be refunded under the
# policy by then, so the transfer is safe to make.
class HostPayoutsJob < ApplicationJob
  queue_as :default

  def perform
    due.find_each do |booking|
      pay(booking)
    rescue => e
      Rails.logger.error("HostPayoutsJob: booking #{booking.id} raised #{e.class}: #{e.message}")
    end
  end

  private

  def due
    Booking.where(status: [ :confirmed, :completed ], host_transfer_id: nil)
           .where(check_in: ..(Date.current - 1))
           .includes(:payments, property: :user)
  end

  def pay(booking)
    return unless booking.paid?

    host = booking.property.user
    return unless host.stripe_ready?

    amount = booking.host_payout_due
    return unless amount.positive?

    transfer = Stripe::Transfer.create(
      amount: (amount * 100).to_i,
      currency: "eur",
      destination: host.stripe_account_id,
      transfer_group: "booking_#{booking.id}",
      metadata: { booking_id: booking.id }
    )

    booking.update!(host_transfer_id: transfer.id, host_paid_at: Time.current)
  end
end
