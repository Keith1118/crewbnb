# Re-prices both locations now that a Mon-Fri stay is counted as four nights
# rather than five. The headline figures are unchanged — Tulfarris €800 and
# Edenderry €500 Mon-Fri — but the nightly rate that produces them is not:
# €200 and €125, where it used to be €160 and €100.
#
# SetMonFriPrices divided by five, so the site advertised €800 while
# Booking#calculate_total (nights * price_per_night, and Mon-Fri is four
# nights) would have charged €640. Bookings are closed, so nothing was ever
# mischarged.
#
# Irreversible on purpose, like the migration it corrects.
class RepriceMonFriAsFourNights < ActiveRecord::Migration[8.1]
  class Property < ActiveRecord::Base
    self.table_name = "properties"
  end

  MON_FRI_NIGHTS = 4

  def up
    tulfarris = Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                               "%tulfarris%", "%tulfarris%", "%tulfarris%")
    edenderry = Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                               "%edenderry%", "%edenderry%", "%edenderry%")

    say "Tulfarris: #{tulfarris.update_all(price_per_night: 800 / MON_FRI_NIGHTS)} listings at €200/night (€800 Mon–Fri)"
    say "Edenderry: #{edenderry.update_all(price_per_night: 500 / MON_FRI_NIGHTS)} listings at €125/night (€500 Mon–Fri)"
  end

  def down
    say "Leaving the four-night Mon–Fri prices in place — the five-night rates undercharged."
  end
end
