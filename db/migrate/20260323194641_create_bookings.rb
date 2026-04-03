class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :property, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :check_in
      t.date :check_out
      t.integer :guests_count
      t.decimal :total_price
      t.integer :status
      t.text :special_requests
      t.string :invoice_reference

      t.timestamps
    end
  end
end
