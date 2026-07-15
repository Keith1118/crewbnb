class AddBusinessFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :company_name, :string
    add_column :users, :vat_number, :string
    add_column :users, :company_address, :text
    add_column :users, :business_verified_at, :datetime
  end
end
