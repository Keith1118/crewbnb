class AddBookingOverlapConstraint < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist"

    # Backstop for the model-level overlap validation: even under concurrent
    # requests, two pending/confirmed bookings can never hold overlapping
    # date ranges on the same property. Status 0 = pending, 1 = confirmed.
    execute <<~SQL
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_no_overlap
      EXCLUDE USING gist (
        property_id WITH =,
        daterange(check_in, check_out) WITH &&
      )
      WHERE (status IN (0, 1));
    SQL
  end

  def down
    execute "ALTER TABLE bookings DROP CONSTRAINT bookings_no_overlap;"
    disable_extension "btree_gist"
  end
end
