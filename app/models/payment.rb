class Payment < ApplicationRecord
  # Associations
  belongs_to :booking

  # Enums
  enum :status, { pending: 0, succeeded: 1, failed: 2, refunded: 3 }

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true
end
