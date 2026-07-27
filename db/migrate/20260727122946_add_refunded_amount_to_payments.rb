class AddRefundedAmountToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :refunded_amount, :decimal
  end
end
