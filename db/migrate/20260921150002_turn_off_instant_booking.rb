# Instant booking is gone from the site: the badge, the toggle on the listing
# form, and the setting itself. The column stays for now — the booking flow
# still reads it, and every row reading false is what puts every listing on
# request-to-book.
class TurnOffInstantBooking < ActiveRecord::Migration[8.1]
  class Property < ActiveRecord::Base
    self.table_name = "properties"
  end

  def up
    say "#{Property.where(instant_book: true).count} listings taken off instant book"
    Property.update_all(instant_book: false)
  end

  def down
    say "Leaving instant booking off — which listings had it isn't recorded."
  end
end
