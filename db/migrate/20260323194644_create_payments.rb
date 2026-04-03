class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.decimal :amount
      t.string :currency
      t.string :stripe_payment_intent_id
      t.integer :status

      t.timestamps
    end
  end
end
