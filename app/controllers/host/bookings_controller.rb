module Host
  class BookingsController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host
    before_action :set_booking, only: [ :show, :update ]

    def index
      bookings = visible_bookings.includes(:property, :user).order(created_at: :desc)

      @pagy, @bookings = pagy(bookings, limit: 10)
    end

    def show
    end

    def update
      case params[:booking][:status]
      when "confirmed"
        notice = case BookingApprover.call(@booking)
        when :charged
          "Booking approved and payment taken — check-in details sent to the guest."
        when :charge_failed
          "Booking approved, but the guest's card was declined. They've been asked to pay by hand and have #{Booking::MANUAL_PAYMENT_GRACE.in_hours.to_i} hours before the dates are released."
        else
          "Booking approved — the guest's card is charged automatically #{Booking::CHARGE_LEAD_TIME.in_days.to_i} days before check-in."
        end
        redirect_to host_booking_path(@booking), notice: notice
      when "cancelled"
        # A host cancelling always refunds the guest in full — they did nothing wrong.
        result = BookingCanceller.call(@booking, by: :host)
        notice = if result.refunded.to_d.positive?
          "Booking cancelled and €#{ActiveSupport::NumberHelper.number_to_rounded(result.refunded, precision: 2)} refunded to the guest."
        else
          "Booking rejected."
        end
        redirect_to host_booking_path(@booking), notice: notice
      else
        redirect_to host_booking_path(@booking), alert: "Invalid status."
      end
    end

    private

    def set_booking
      @booking = visible_bookings.find(params[:id])
    end

    # Admins are allowed into the host area by require_host, but they own no
    # properties — scoping to current_user.properties 404'd every booking for
    # them, including from the "View Booking" link in the host email.
    def visible_bookings
      current_user.admin? ? Booking.all : Booking.where(property: current_user.properties)
    end

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
