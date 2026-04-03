class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: [:show, :update]

  def index
    @pagy, @bookings = pagy(
      current_user.bookings.includes(:property).order(created_at: :desc),
      limit: 10
    )
  end

  def show
    authorize @booking
  end

  def new
    @property = Property.find(params[:property_id])
    @booking = Booking.new
  end

  def create
    @property = Property.find(params[:property_id])
    @booking = current_user.bookings.build(booking_params)
    @booking.property = @property
    @booking.status = @property.instant_book? ? :confirmed : :pending

    if @booking.save
      BookingMailer.confirmation(@booking).deliver_later if @booking.confirmed?
      BookingMailer.new_booking_host(@booking).deliver_later
      redirect_to @booking, notice: "Booking #{@property.instant_book? ? 'confirmed' : 'submitted for approval'}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @booking

    if @booking.update(status: params[:booking][:status])
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

  def set_booking
    @booking = Booking.find(params[:id])
  end

  def booking_params
    params.require(:booking).permit(:check_in, :check_out, :guests_count, :special_requests)
  end
end
