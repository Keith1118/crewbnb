class Amenity < ApplicationRecord
  # Enums
  enum :category, { work: 0, comfort: 1, safety: 2 }

  # Associations
  has_many :property_amenities, dependent: :destroy
  has_many :properties, through: :property_amenities

  # Validations
  validates :name, presence: true
end
