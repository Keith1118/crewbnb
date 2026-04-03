class CreateAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :availabilities do |t|
      t.references :property, null: false, foreign_key: true
      t.date :date
      t.boolean :available
      t.decimal :custom_price

      t.timestamps
    end
  end
end
