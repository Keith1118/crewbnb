class CreateContactSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_submissions do |t|
      t.string :name
      t.string :email
      t.string :subject
      t.text :message
      t.integer :status

      t.timestamps
    end
  end
end
