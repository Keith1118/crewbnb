class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :property_type
      t.string :address
      t.string :city
      t.string :country
      t.float :latitude
      t.float :longitude
      t.decimal :price_per_night
      t.integer :max_guests
      t.integer :bedrooms
      t.integer :bathrooms
      t.string :wifi_speed
      t.boolean :has_desk, default: false
      t.boolean :has_meeting_room, default: false
      t.boolean :has_printer, default: false
      t.boolean :has_parking, default: false
      t.integer :status, default: 0
      t.boolean :instant_book, default: false

      t.timestamps
    end
  end
end
