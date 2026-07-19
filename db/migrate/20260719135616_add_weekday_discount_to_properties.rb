class AddWeekdayDiscountToProperties < ActiveRecord::Migration[8.1]
  def change
    # Weekday (Mon–Fri) discount vs a typical weekend/tourist rate, in percent.
    # Default backfills existing listings so they stay valid.
    add_column :properties, :weekday_discount, :integer, default: 15, null: false
  end
end
