class Property < ApplicationRecord
  include PgSearch::Model

  # Associations
  belongs_to :user

  has_many :property_images, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :reviews, through: :bookings
  has_many :property_amenities, dependent: :destroy
  has_many :amenities, through: :property_amenities
  has_many :availabilities, dependent: :destroy
  has_many :favorites, dependent: :destroy

  # Attachments
  has_many_attached :images

  # Enums
  enum :status, { draft: 0, published: 1, archived: 2 }

  # Search
  pg_search_scope :search_by_text,
    against: [ :title, :description, :city ],
    using: { tsearch: { prefix: true } }

  # Geocoding
  geocoded_by :full_address
  after_validation :geocode, if: ->(obj) {
    (obj.address_changed? || obj.city_changed? || obj.country_changed?) &&
      !(obj.latitude_changed? || obj.longitude_changed?)
  }

  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :price_per_night, presence: true, numericality: { greater_than: 0 }
  validates :weekday_discount, presence: true,
            inclusion: { in: [ 10, 15, 20, 25 ], message: "must be 10, 15, 20 or 25%" }
  validates :max_guests, presence: true, numericality: { greater_than: 0 }
  validates :bedrooms, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :bathrooms, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :published, -> { where(status: :published) }

  # Methods
  def full_address
    [ address, city, country ].compact.join(", ")
  end

  def average_rating
    reviews.average(:rating)&.round(1)
  end

  def weekly_price
    (price_per_night * 5).round
  end

  # The typical weekend/tourist nightly rate this weekday rate undercuts,
  # implied by the host's chosen weekday discount. Used to show the saving.
  def typical_weekend_rate
    return if weekday_discount.to_i <= 0

    (price_per_night / (1 - (weekday_discount / 100.0))).round
  end

  def available_between?(check_in, check_out)
    return false if bookings.blocking.overlapping(check_in, check_out).exists?
    return false if availabilities.where(available: false, date: check_in...check_out).exists?

    true
  end

  def next_available_date
    last_blocking = bookings.blocking.where("check_out > ?", Date.current).order(:check_out)
    date = Date.current
    last_blocking.each do |booking|
      break if booking.check_in > date

      date = [ date, booking.check_out ].max
    end
    date
  end
end
