class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_business_verification, only: [ :new, :create ]
  rate_limit to: 10, within: 1.minute, only: :create,
             with: -> { redirect_to properties_path, alert: "Too many booking attempts. Please wait a minute and try again." }
  before_action :set_booking, only: [ :show, :update ]

  def index
    scope = current_user.bookings.includes(:property).order(created_at: :desc)

    scope = case params[:status]
    when "upcoming"
      scope.blocking.where(check_in: Date.current..)
    when "past"
      scope.where.not(status: :cancelled).where(check_out: ...Date.current)
    when "cancelled"
      scope.cancelled
    else
      scope
    end

    @pagy, @bookings = pagy(scope, limit: 10)
  end

  def show
    authorize @booking
  end

  def new
    @property = Property.published.find(params[:property_id])
    @booking = Booking.new(
      check_in: safe_date(params[:check_in]),
      check_out: safe_date(params[:check_out]),
      guests_count: params[:guests].presence
    )
  end

  def create
    @property = Property.published.find(params[:property_id])
    @booking = current_user.bookings.build(booking_params)
    @booking.property = @property
    @booking.status = :pending

    if @booking.save
      if @property.instant_book? && StripeConfig.configured?
        redirect_to new_booking_payment_path(@booking), notice: "Booking created — complete payment to confirm your stay."
      else
        # No online payment available (or request-to-book listing): route through host approval.
        BookingMailer.new_booking_host(@booking).deliver_later
        AutoMessenger.booking_requested(@booking)
        redirect_to @booking, notice: "Booking request sent. We'll email you as soon as the host confirms."
      end
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::ExclusionViolation)

    @booking.errors.add(:base, "Those dates were just booked by someone else. Please pick different dates.")
    render :new, status: :unprocessable_entity
  end

  def update
    authorize @booking
    new_status = params.dig(:booking, :status).to_s

    unless allowed_status_changes.include?(new_status)
      redirect_to @booking, alert: "That booking change isn't allowed." and return
    end

    if @booking.update(status: new_status)
      if @booking.cancelled?
        BookingMailer.cancellation(@booking).deliver_later
      else
        BookingMailer.status_update(@booking).deliver_later
      end
      redirect_to @booking, notice: "Booking status updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  # Only verified businesses can book. Remember where they were headed so we can
  # drop them straight back into the booking after they verify.
  def require_business_verification
    return if current_user.business_verified?

    booking = params[:booking] || {}
    session[:after_verification] = new_property_booking_path(
      params[:property_id],
      check_in: booking[:check_in] || params[:check_in],
      check_out: booking[:check_out] || params[:check_out],
      guests: booking[:guests_count] || params[:guests]
    )
    redirect_to new_business_verification_path,
                notice: "Crewbnb is for businesses — verify your company's VAT number to book."
  end

  def set_booking
    @booking = Booking.find(params[:id])
  end

  def booking_params
    params.require(:booking).permit(:check_in, :check_out, :guests_count, :special_requests)
  end

  def safe_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # Guests may only cancel their own booking. Hosts/admins may confirm,
  # cancel, or mark a stay completed.
  def allowed_status_changes
    if current_user.admin? || @booking.property.user_id == current_user.id
      %w[confirmed cancelled completed]
    elsif @booking.user_id == current_user.id && (@booking.pending? || @booking.confirmed?)
      %w[cancelled]
    else
      []
    end
  end
end
