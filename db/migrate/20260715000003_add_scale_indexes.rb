class AddScaleIndexes < ActiveRecord::Migration[8.1]
  def change
    # Booking availability/overlap checks and status-scoped lists
    add_index :bookings, [ :property_id, :status ]
    add_index :bookings, [ :status, :check_in ]
    add_index :bookings, [ :status, :check_out ]

    # Host-blocked dates lookups (one row per property+date)
    add_index :availabilities, [ :property_id, :date ], unique: true

    # Unread counts per conversation
    add_index :messages, [ :conversation_id, :read_at ]

    # Public catalogue: published scope, city filter, geo search
    add_index :properties, :status
    add_index :properties, :city
    add_index :properties, [ :latitude, :longitude ]

    # Inbox ordering
    add_index :conversations, :updated_at
  end
end
