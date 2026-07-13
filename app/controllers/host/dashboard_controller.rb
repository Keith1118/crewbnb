module Host
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_host

    def index
      @property_count = current_user.properties.count
      @booking_count = Booking.where(property: current_user.properties).count
      @earnings = Booking.where(property: current_user.properties)
                         .where(status: [ :confirmed, :completed ])
                         .sum(:total_price)
      @recent_bookings = Booking.where(property: current_user.properties)
                                .includes(:property, :user)
                                .order(created_at: :desc)
                                .limit(10)
    end

    private

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
