class AddPaymentRequestedSentAtToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :payment_requested_sent_at, :datetime
  end
end
