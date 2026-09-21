# Prices the two locations for a Monday-to-Friday stay: Tulfarris at €800,
# Edenderry at €500. weekly_price is five nights, so the nightly rate carries
# the Mon–Fri figure: €160 and €100.
#
# Irreversible on purpose — the old rates weren't recorded anywhere, so a
# rollback leaves these in place and they'd be reset from the admin screen.
class SetMonFriPrices < ActiveRecord::Migration[8.1]
  class Property < ActiveRecord::Base
    self.table_name = "properties"
  end

  MON_FRI_NIGHTS = 5

  def up
    tulfarris = Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                               "%tulfarris%", "%tulfarris%", "%tulfarris%")
    edenderry = Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                               "%edenderry%", "%edenderry%", "%edenderry%")

    say "Tulfarris: #{tulfarris.update_all(price_per_night: 800 / MON_FRI_NIGHTS)} listings at €800 Mon–Fri"
    say "Edenderry: #{edenderry.update_all(price_per_night: 500 / MON_FRI_NIGHTS)} listings at €500 Mon–Fri"
  end

  def down
    say "Leaving the Mon–Fri prices in place — the previous rates weren't recorded."
  end
end
