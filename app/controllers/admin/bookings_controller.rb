module Admin
  class BookingsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @pagy, @bookings = pagy(
        Booking.includes(:user, :property).order(created_at: :desc),
        limit: 20
      )
    end

    def show
      @booking = Booking.find(params[:id])
    end

    private

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end
  end
end
