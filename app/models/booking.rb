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
  # awaiting_payment: we hold the guest's card but couldn't charge it (expired,
  # declined, or the bank wants 3-D Secure, which needs the guest present). They
  # have until payment_due_by to pay by hand before the stay is released.
  enum :status, { pending: 0, confirmed: 1, cancelled: 2, completed: 3, awaiting_payment: 4 }, default: :pending

  # Nobody is charged at the moment of booking. We take the card, then charge it
  # this far ahead of check-in — or straight away if check-in is nearer than that.
  CHARGE_LEAD_TIME = 10.days

  # Free cancellation up to here. It sits AFTER the charge deliberately: a guest
  # who cancels in that window is refunded in full, and the two dates never need
  # explaining separately — money moves, then three days later the door closes.
  FREE_CANCELLATION_WINDOW = 7.days

  # How long a guest gets to pay by hand once an automatic charge has failed.
  MANUAL_PAYMENT_GRACE = 72.hours

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
  scope :blocking, -> { where(status: [ :pending, :confirmed, :awaiting_payment ]) }
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

  # Can this booking be charged online right now? Needs Stripe wired up and the
  # host able to receive money — otherwise the stay is settled off-platform and
  # host approval alone confirms it.
  def payable_online?
    StripeConfig.configured? && property.user.stripe_ready? && !paid?
  end

  # ----- Scheduled charging -------------------------------------------------

  # The day we take the money. Never in the past: a stay booked inside the lead
  # time is charged as soon as it's confirmed.
  def charge_on
    return nil unless check_in

    [ check_in - CHARGE_LEAD_TIME, Date.current ].max
  end

  def charge_due?
    return false unless confirmed? && !paid? && stripe_payment_method_id.present?

    charge_on <= Date.current
  end

  # ----- Cancellation -------------------------------------------------------

  def free_cancellation_until
    return nil unless check_in

    check_in - FREE_CANCELLATION_WINDOW
  end

  def free_cancellation?
    return true unless check_in

    Date.current <= free_cancellation_until
  end

  # What a guest gets back if they cancel right now. Full refund inside the free
  # window; after it, whatever the host's listing promises.
  def refund_on_cancellation
    return 0 unless paid?
    return amount_paid if free_cancellation?

    (amount_paid * property.cancellation_refund_rate).round(2)
  end

  def amount_paid
    payments.succeeded.sum(:amount) - payments.sum(:refunded_amount).to_d
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
