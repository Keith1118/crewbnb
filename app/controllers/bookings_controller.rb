class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_guest_account
  before_action :ensure_bookings_open, only: [ :new, :create ]
  before_action :require_business_verification, only: [ :new, :create ]
  rate_limit to: 10, within: 1.minute, only: :create,
             with: -> { redirect_to properties_path, alert: "Too many booking attempts. Please wait a minute and try again." }
  before_action :set_booking, only: [ :show, :update, :invoice ]

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
      if @booking.payable_online?
        # Take a card now, charge it nearer check-in. BookingCardsController
        # picks the booking up from there — including telling the host.
        redirect_to new_booking_card_path(@booking),
                    notice: "Almost there — save a card to hold these dates. You won't be charged today."
      else
        # No online payment available: the stay is settled off-platform, so it
        # goes straight to the host for approval.
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

    # Approving a request-to-book stay goes through the same path as the host
    # dashboard, so approval and charging behave identically wherever it's done.
    if new_status == "confirmed" && @booking.pending?
      BookingApprover.call(@booking)
      redirect_to @booking, notice: "Booking approved." and return
    end

    # Cancelling refunds what the policy owes, so it can't be a plain status change.
    if new_status == "cancelled" && !@booking.cancelled?
      redirect_to @booking, notice: cancellation_notice and return
    end

    if @booking.update(status: new_status)
      BookingMailer.status_update(@booking).deliver_later
      redirect_to @booking, notice: "Booking status updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Printable invoice — visible to the guest, the host, or an admin.
  def invoice
    unless @booking.user_id == current_user.id ||
           @booking.property.user_id == current_user.id ||
           current_user.admin?
      redirect_to(bookings_path, alert: "You're not authorised to view that invoice.") and return
    end

    render layout: "invoice"
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
                notice: "Crewbase is for businesses — verify your company's VAT number to book."
  end

  # Pre-launch guard: block booking placement until BOOKINGS_OPEN is set.
  def ensure_bookings_open
    return if bookings_open?

    redirect_back fallback_location: property_path(params[:property_id]),
                  alert: "Bookings aren't open just yet — we're launching very soon. Please check back shortly."
  end

  def set_booking
    @booking = Booking.find(params[:id])
  end

  # Whoever cancels, the refund follows the policy — except a host or admin
  # cancelling, which always refunds in full.
  def cancellation_notice
    by = @booking.user_id == current_user.id ? :guest : :host
    result = BookingCanceller.call(@booking, by: by)

    if result.refunded.to_d.positive?
      "Booking cancelled. €#{ActiveSupport::NumberHelper.number_to_rounded(result.refunded, precision: 2)} has been refunded to the guest's card."
    elsif @booking.paid?
      "Booking cancelled. No refund is due under this listing's cancellation policy."
    else
      "Booking cancelled."
    end
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
    elsif @booking.user_id == current_user.id && (@booking.pending? || @booking.confirmed? || @booking.awaiting_payment?)
      %w[cancelled]
    else
      []
    end
  end
end
