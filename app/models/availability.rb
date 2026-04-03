class Availability < ApplicationRecord
  # Associations
  belongs_to :property

  # Validations
  validates :date, presence: true
  validates :date, uniqueness: { scope: :property_id }
end
