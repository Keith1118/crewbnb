class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :reviewer, null: false, foreign_key: { to_table: :users }
      t.integer :rating, null: false
      t.text :comment
      t.string :reviewable_type, null: false
      t.bigint :reviewable_id, null: false

      t.timestamps
    end

    add_index :reviews, [:reviewable_type, :reviewable_id]
  end
end
