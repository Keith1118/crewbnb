# The Edenderry rooms carried a room number and a sales line in the title
# ("Room 8 · Triple Room for Crews — Best Value Per Bed in Edenderry"). What a
# company needs is the room type, so that's all the title is now.
#
# featured_position fixes the order of the home page: the three Tulfarris
# properties, then double, twin, triple.
class NameAndOrderTheEdenderryRooms < ActiveRecord::Migration[8.1]
  class Property < ActiveRecord::Base
    self.table_name = "properties"
  end

  ROOM_TYPES = { "double" => "Double Room", "twin" => "Twin Room", "triple" => "Triple Room" }.freeze

  def up
    edenderry = Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                               "%edenderry%", "%edenderry%", "%edenderry%")

    ROOM_TYPES.each do |keyword, name|
      rooms = edenderry.where("title ILIKE ?", "%#{keyword}%")
      say "#{name}: renaming #{rooms.count} listings"
      rooms.update_all(title: name)
    end

    order_the_home_page
  end

  # Titles can't be restored — they weren't recorded anywhere.
  def down
    Property.update_all(featured_position: nil)
  end

  private

  def order_the_home_page
    position = 0

    Property.where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                   "%tulfarris%", "%tulfarris%", "%tulfarris%")
            .where(featured: true)
            .order(:created_at)
            .each { |property| property.update_columns(featured_position: position += 1) }

    ROOM_TYPES.each_value do |name|
      Property.where(title: name, featured: true)
              .order(:created_at)
              .each { |property| property.update_columns(featured_position: position += 1) }
    end
  end
end
