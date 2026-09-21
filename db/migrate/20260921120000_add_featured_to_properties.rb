class AddFeaturedToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :featured, :boolean, default: false, null: false
    add_index :properties, :featured
  end
end
