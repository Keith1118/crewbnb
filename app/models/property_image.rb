class PropertyImage < ApplicationRecord
  belongs_to :property

  has_one_attached :image

  validates :position, presence: true
end
