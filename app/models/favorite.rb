class Favorite < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :property

  # Validations
  validates :property_id, uniqueness: { scope: :user_id }
end
