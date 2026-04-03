class Booking < ApplicationRecord
  # Associations
  belongs_to :property
  belongs_to :user
  has_many :payments, dependent: :destroy
  has_one :review

  # Enums
  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3 }

  # Validations
  validates :check_in, presence: true
  validates :check_out, presence: true
  validates :guests_count, presence: true, numericality: { greater_than: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :check_out_after_check_in

  # Callbacks
  before_validation :set_total_price
  before_validation :generate_invoice_reference, on: :create

  # Methods
  def nights
    return 0 unless check_in && check_out

    (check_out - check_in).to_i
  end

  def calculate_total
    return 0 unless property && check_in && check_out

    nights * property.price_per_night
  end

  private

  def check_out_after_check_in
    return unless check_in && check_out

    errors.add(:check_out, "must be after check-in date") if check_out <= check_in
  end

  def set_total_price
    self.total_price = calculate_total if total_price.blank? || total_price.zero?
  end

  def generate_invoice_reference
    self.invoice_reference ||= "WS-#{SecureRandom.hex(6).upcase}"
  end
end
