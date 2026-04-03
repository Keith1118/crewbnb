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
    against: [:title, :description, :city],
    using: { tsearch: { prefix: true } }

  # Geocoding
  geocoded_by :full_address
  after_validation :geocode, if: ->(obj) { obj.address_changed? || obj.city_changed? || obj.country_changed? }

  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :price_per_night, presence: true, numericality: { greater_than: 0 }
  validates :max_guests, presence: true, numericality: { greater_than: 0 }
  validates :bedrooms, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :bathrooms, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :published, -> { where(status: :published) }

  # Methods
  def full_address
    [address, city, country].compact.join(", ")
  end

  def average_rating
    reviews.average(:rating)&.round(2)
  end
end
