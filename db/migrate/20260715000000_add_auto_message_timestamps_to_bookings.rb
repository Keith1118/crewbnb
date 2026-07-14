class AddAutoMessageTimestampsToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :request_ack_sent_at, :datetime
    add_column :bookings, :confirmation_sent_at, :datetime
    add_column :bookings, :reminder_sent_at, :datetime
    add_column :bookings, :review_request_sent_at, :datetime
  end
end
