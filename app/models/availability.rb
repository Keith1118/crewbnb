class Availability < ApplicationRecord
  # Associations
  belongs_to :property

  # Where this row came from. Manual (host-set) rows always win over iCal ones,
  # so an iCal sync only ever replaces its own :ical rows.
  enum :source, { manual: 0, ical: 1 }

  # Validations
  validates :date, presence: true
  validates :date, uniqueness: { scope: :property_id }
end
