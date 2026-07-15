class AddVatRateToUsers < ActiveRecord::Migration[8.1]
  def change
    # A host's VAT rate (%), used to back VAT out of the inclusive price on invoices.
    add_column :users, :vat_rate, :decimal, precision: 5, scale: 2
  end
end
