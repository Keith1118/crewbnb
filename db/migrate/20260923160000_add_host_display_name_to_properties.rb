# The public listing says who hosts a place. That name came from the owning
# User, so every property on one account read the same name — all of Tulfarris
# and Edenderry showed "Hosted by Keith" because they share host1@crewbase.ie.
#
# This holds the name shown for a single listing. It's display only: the owning
# account is unchanged, and that's still what bookings, payouts and the host
# dashboard work from. Blank falls back to the account's name.
class AddHostDisplayNameToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :host_display_name, :string
  end
end
