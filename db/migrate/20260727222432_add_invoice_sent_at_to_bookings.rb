class AddInvoiceSentAtToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :invoice_sent_at, :datetime
  end
end
