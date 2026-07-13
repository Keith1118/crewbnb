class AddListingDetailsToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :bed_configuration, :string
    add_column :properties, :house_rules, :text
    add_column :properties, :check_in_time, :string, default: "3:00 PM"
    add_column :properties, :check_out_time, :string, default: "10:30 AM"
    add_column :properties, :nearby_attractions, :text
  end
end
