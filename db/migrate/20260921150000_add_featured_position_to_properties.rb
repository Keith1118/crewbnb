class AddFeaturedPositionToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :featured_position, :integer
  end
end
