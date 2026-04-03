module Host
  class BookingsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_host
    before_action :set_booking, only: [:show, :update]

    def index
      bookings = Booking.where(property: current_user.properties)
                        .includes(:property, :user)
                        .order(created_at: :desc)

      @pagy, @bookings = pagy(bookings, limit: 10)
    end

    def show
    end

    def update
      case params[:booking][:status]
      when "confirmed"
        @booking.confirmed!
        redirect_to host_booking_path(@booking), notice: "Booking approved."
      when "cancelled"
        @booking.cancelled!
        redirect_to host_booking_path(@booking), notice: "Booking rejected."
      else
        redirect_to host_booking_path(@booking), alert: "Invalid status."
      end
    end

    private

    def set_booking
      @booking = Booking.where(property: current_user.properties).find(params[:id])
    end

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
