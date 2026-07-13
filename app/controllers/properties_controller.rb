class PropertiesController < ApplicationController
  before_action :authenticate_user!, only: [ :favorite, :unfavorite ]
  before_action :set_property, only: [ :show, :favorite, :unfavorite ]

  def index
    properties = Property.published

    # "My favorites" filter from the account menu
    if params[:favorites].present? && user_signed_in?
      properties = properties.where(id: current_user.favorites.select(:property_id))
    end

    # Full-text search via pg_search
    if params[:query].present?
      properties = properties.search_by_text(params[:query])
    end

    # Filters
    properties = properties.where(city: params[:city]) if params[:city].present?
    properties = properties.where(property_type: params[:property_type]) if params[:property_type].present?
    properties = properties.where("price_per_night >= ?", params[:min_price]) if params[:min_price].present?
    properties = properties.where("price_per_night <= ?", params[:max_price]) if params[:max_price].present?
    properties = properties.where("max_guests >= ?", params[:guests]) if params[:guests].present?

    # Date availability filtering
    if params[:check_in].present? && params[:check_out].present?
      booked_property_ids = Booking.where(status: [ :pending, :confirmed ])
                                   .where("check_in < ? AND check_out > ?", params[:check_out], params[:check_in])
                                   .select(:property_id)
      properties = properties.where.not(id: booked_property_ids)
    end

    # Sorting
    case params[:sort]
    when "price_asc"
      properties = properties.order(price_per_night: :asc)
    when "price_desc"
      properties = properties.order(price_per_night: :desc)
    when "newest"
      properties = properties.order(created_at: :desc)
    else
      properties = properties.order(created_at: :desc)
    end

    @pagy, @properties = pagy(properties.with_attached_images, limit: 12)
  end

  def show
    @reviews = @property.reviews.includes(:reviewer).order(created_at: :desc)
    @booking = Booking.new
    @is_favorited = current_user&.favorites&.exists?(property: @property)
  end

  def favorite
    current_user.favorites.find_or_create_by(property: @property)
    redirect_to @property, notice: "Property added to your favorites."
  end

  def unfavorite
    current_user.favorites.find_by(property: @property)&.destroy
    redirect_to @property, notice: "Property removed from your favorites."
  end

  private

  def set_property
    @property = Property.find(params[:id])
  end
end
