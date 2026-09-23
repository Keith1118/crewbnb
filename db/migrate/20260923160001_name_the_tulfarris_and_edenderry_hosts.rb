# Who each listing is hosted by, as the owners are actually known:
#
#   Three-Bedroom Home, Tulfarris  → Lisa
#   Retreat in Tulfarris           → Ramzi
#   Tully's Home, Tulfarris        → left blank, so it stays "Keith"
#   Edenderry (all of them)        → Rory
#
# Matched on title and address rather than id, which differs between
# environments.
class NameTheTulfarrisAndEdenderryHosts < ActiveRecord::Migration[8.1]
  class Property < ActiveRecord::Base
    self.table_name = "properties"
  end

  def up
    say "Lisa: #{Property.where('title ILIKE ?', '%Three-Bedroom Home in Tulfarris%').update_all(host_display_name: 'Lisa')} listing"
    say "Ramzi: #{Property.where('title ILIKE ?', '%Retreat in Tulfarris%').update_all(host_display_name: 'Ramzi')} listing"

    edenderry = Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                               "%edenderry%", "%edenderry%", "%edenderry%")
    say "Rory: #{edenderry.update_all(host_display_name: 'Rory')} Edenderry listings"
  end

  def down
    Property.where(host_display_name: [ "Lisa", "Ramzi", "Rory" ]).update_all(host_display_name: nil)
  end
end
