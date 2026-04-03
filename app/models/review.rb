class Review < ApplicationRecord
  # Associations
  belongs_to :booking
  belongs_to :reviewer, class_name: "User"
  belongs_to :reviewable, polymorphic: true

  # Validations
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :comment, presence: true
end
