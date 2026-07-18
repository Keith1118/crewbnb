module Host
  class DashboardController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host

    def index
      props = current_user.properties
      @property_count = props.count
      @property_ids = props.pluck(:id)
      bookings = Booking.where(property_id: @property_ids)
      today = @today = Date.current

      # Needs attention — requests to approve/reject
      @pending = bookings.pending.includes(:property, :user).order(:check_in)

      # Today at a glance
      @arrivals_today   = bookings.blocking.where(check_in: today).includes(:property, :user).order(:check_in)
      @departures_today = bookings.blocking.where(check_out: today).includes(:property, :user)
      @in_house = bookings.confirmed.where("check_in <= ? AND check_out > ?", today, today)
                          .includes(:property, :user)

      # Upcoming arrivals (next 14 days)
      @upcoming = bookings.blocking.where(check_in: (today + 1)..(today + 14.days))
                          .includes(:property, :user).order(:check_in).limit(8)

      # Occupancy this month across all listings
      m_start = today.beginning_of_month
      m_end   = today.end_of_month
      capacity = @property_ids.size * m_end.day
      booked_nights = bookings.blocking
                              .where("check_in <= ? AND check_out > ?", m_end, m_start)
                              .sum do |b|
        ([ b.check_out, m_end + 1 ].min - [ b.check_in, m_start ].max).to_i
      end
      @occupancy = capacity.zero? ? 0 : ((booked_nights.to_f / capacity) * 100).round
      @booked_nights_month = booked_nights

      # Money — host earnings are net of Crewbase's commission
      net = 1 - Booking::COMMISSION_RATE
      earned = bookings.where(status: [ :confirmed, :completed ])
      @revenue_month = (earned.where(check_in: m_start..m_end).sum(:total_price) * net).round(2)
      @earnings = (earned.sum(:total_price) * net).round(2)

      @upcoming_count = bookings.blocking.where("check_out >= ?", today).count
      @avg_rating = Review.joins(booking: :property)
                          .where(properties: { user_id: current_user.id }).average(:rating)

      @recent_bookings = bookings.includes(:property, :user).order(created_at: :desc).limit(6)
    end

    private

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
