class AddIcalFieldsToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :listing_url, :string
    add_column :properties, :ical_url, :string
    add_column :properties, :ical_last_synced_at, :datetime
  end
end
