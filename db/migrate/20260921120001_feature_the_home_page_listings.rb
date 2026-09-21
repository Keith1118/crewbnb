# The six the home page opens with: the three Tulfarris properties, plus one
# double, one twin and one triple from the Edenderry rooms. Newest-first alone
# gave two doubles and no twin, so the selection is explicit. Staff can change
# the picks from the listing form afterwards — this only sets the starting six.
class FeatureTheHomePageListings < ActiveRecord::Migration[8.1]
  class Property < ActiveRecord::Base
    self.table_name = "properties"
  end

  def up
    ids = Property.where("title ILIKE ?", "%tulfarris%").pluck(:id)

    %w[double twin triple].each do |room_type|
      ids << Property.where("title ILIKE ?", "%#{room_type}%")
                     .where("title ILIKE ? OR city ILIKE ? OR address ILIKE ?",
                            "%edenderry%", "%edenderry%", "%edenderry%")
                     .order(created_at: :desc)
                     .pick(:id)
    end

    Property.where(id: ids.compact).update_all(featured: true)
  end

  def down
    Property.update_all(featured: false)
  end
end
