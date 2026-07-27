class AddScheduledChargingToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :stripe_payment_method_id, :string
    add_column :bookings, :payment_due_by, :datetime
    add_column :bookings, :charge_failed_at, :datetime
  end
end
