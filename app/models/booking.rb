class Booking < ApplicationRecord
  # Crewbase's commission, taken out of the host's payout (never added to the
  # guest's price — the guest always pays exactly the listed total).
  COMMISSION_RATE = BigDecimal("0.075") # 7.5%

  # Associations
  belongs_to :property
  belongs_to :user
  has_many :payments, dependent: :destroy
  has_one :review

  # Enums
  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3 }, default: :pending

  # Validations
  validates :check_in, presence: true
  validates :check_out, presence: true
  validates :guests_count, presence: true, numericality: { greater_than: 0 }
  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :check_out_after_check_in
  validate :check_in_not_in_past, on: :create
  validate :guests_within_capacity
  validate :dates_not_double_booked
  validate :dates_not_blocked

  # Callbacks
  before_validation :set_total_price
  before_validation :generate_invoice_reference, on: :create

  # Scopes
  scope :blocking, -> { where(status: [ :pending, :confirmed ]) }
  scope :overlapping, ->(check_in, check_out) { where("check_in < ? AND check_out > ?", check_out, check_in) }

  # Methods
  def nights
    return 0 unless check_in && check_out

    (check_out - check_in).to_i
  end

  # ----- Invoice figures (invoice is FROM the host, TO the guest's business) -----
  # The guest always pays the listed price; if the host is VAT-registered the
  # VAT is simply backed out of that inclusive total.

  # Default Irish short-term accommodation VAT rate when a registered host
  # hasn't set their own.
  DEFAULT_VAT_RATE = BigDecimal("13.5")

  def supplier
    property.user
  end

  def vat_registered_supplier?
    supplier.vat_number.present?
  end

  def invoice_vat_rate
    return BigDecimal("0") unless vat_registered_supplier?

    supplier.vat_rate.presence || DEFAULT_VAT_RATE
  end

  def invoice_gross
    total_price || 0
  end

  def invoice_net
    return invoice_gross unless vat_registered_supplier?

    (invoice_gross / (1 + invoice_vat_rate / 100)).round(2)
  end

  def invoice_vat
    (invoice_gross - invoice_net).round(2)
  end

  # Crewbase's cut of this booking (7.5% of the total the guest pays).
  def commission_amount
    return 0 unless total_price

    (total_price * COMMISSION_RATE).round(2)
  end

  # What the host actually receives after commission.
  def host_payout
    return 0 unless total_price

    total_price - commission_amount
  end

  def paid?
    payments.succeeded.exists?
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

  def check_in_not_in_past
    return unless check_in

    errors.add(:check_in, "can't be in the past") if check_in < Date.current
  end

  def guests_within_capacity
    return unless property && guests_count

    if guests_count > property.max_guests
      errors.add(:guests_count, "exceeds this property's capacity of #{property.max_guests}")
    end
  end

  def dates_not_double_booked
    return unless property && check_in && check_out
    return if cancelled?

    clash = property.bookings.blocking.overlapping(check_in, check_out)
    clash = clash.where.not(id: id) if persisted?

    errors.add(:base, "Those dates are no longer available for this property") if clash.exists?
  end

  def dates_not_blocked
    return unless property && check_in && check_out
    return if cancelled?

    if property.availabilities.where(available: false, date: check_in...check_out).exists?
      errors.add(:base, "Some of those dates have been blocked by the host and can't be booked")
    end
  end

  def set_total_price
    if total_price.blank? || total_price.zero? || check_in_changed? || check_out_changed?
      self.total_price = calculate_total
    end
  end

  def generate_invoice_reference
    self.invoice_reference ||= "CB-#{SecureRandom.hex(6).upcase}"
  end
end
