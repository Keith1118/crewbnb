class AddHostPayoutToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :host_transfer_id, :string
    add_column :bookings, :host_paid_at, :datetime
  end
end
