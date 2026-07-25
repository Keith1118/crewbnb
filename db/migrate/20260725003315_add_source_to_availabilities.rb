class AddSourceToAvailabilities < ActiveRecord::Migration[8.1]
  def change
    # 0 = manual (host-set, wins), 1 = ical (synced from an external calendar feed)
    add_column :availabilities, :source, :integer, null: false, default: 0
  end
end
