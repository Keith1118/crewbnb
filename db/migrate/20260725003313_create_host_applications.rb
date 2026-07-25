class CreateHostApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :host_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :applicant_type, null: false, default: 0
      t.string :property_address
      t.string :listing_url
      t.string :ical_url
      t.string :company_name
      t.integer :entity_type
      t.integer :status, null: false, default: 0
      t.text :review_notes
      t.datetime :reviewed_at
      # Nullify (don't block) if the reviewing admin or the built listing is later
      # deleted — the application record should survive with a dangling reference.
      t.references :reviewed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :property, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :host_applications, :status
  end
end
