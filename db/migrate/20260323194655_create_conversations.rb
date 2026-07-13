class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :participant_1, null: false, foreign_key: { to_table: :users }
      t.references :participant_2, null: false, foreign_key: { to_table: :users }
      t.references :property, null: false, foreign_key: true

      t.timestamps
    end

    add_index :conversations, [ :participant_1_id, :participant_2_id, :property_id ], unique: true, name: "index_conversations_on_participants_and_property"
  end
end
