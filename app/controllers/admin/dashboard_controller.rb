module Admin
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @total_users = User.count
      @total_properties = Property.count
      @total_bookings = Booking.count
      @total_revenue = Booking.where(status: [ :confirmed, :completed ]).sum(:total_price)

      @recent_users = User.order(created_at: :desc).limit(5)
      @recent_bookings = Booking.includes(:user, :property).order(created_at: :desc).limit(10)
      @recent_properties = Property.includes(:user).order(created_at: :desc).limit(5)
    end

    private

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end
  end
end
