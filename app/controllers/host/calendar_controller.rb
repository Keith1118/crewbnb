module Host
  class CalendarController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host

    # GET /host/calendar
    def index
      @properties = current_user.properties.order(:title)
      @property = @properties.find_by(id: params[:property_id]) || @properties.first
      @month = parse_month(params[:month])
      load_calendar if @property
    end

    # PATCH /host/calendar/toggle — flip a single day open <-> blocked
    def toggle
      @property = current_user.properties.find(params[:property_id])
      date = safe_date(params[:date])

      if date.nil? || date < Date.current
        flash[:alert] = "You can't change past dates."
      elsif booked_on?(@property, date)
        flash[:alert] = "That date already has a booking and can't be blocked."
      else
        av = @property.availabilities.find_or_initialize_by(date: date)
        if av.persisted? && av.available == false
          av.destroy # was blocked -> reopen
        else
          av.update(available: false) # open -> block
        end
      end

      redirect_to host_calendar_path(property_id: @property.id, month: month_param(date))
    end

    # PATCH /host/calendar/block_range — block or open a whole range at once
    def block_range
      @property = current_user.properties.find(params[:property_id])
      from = safe_date(params[:from])
      to   = safe_date(params[:to])
      action = params[:range_action].to_s # "block" or "open"

      if from.nil? || to.nil? || to < from
        flash[:alert] = "Please pick a valid start and end date."
      else
        changed = apply_range(@property, from, to, action)
        flash[:notice] = "#{action == 'open' ? 'Opened' : 'Blocked'} #{changed} #{'night'.pluralize(changed)}."
      end

      redirect_to host_calendar_path(property_id: @property.id, month: month_param(from))
    end

    private

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end

    def parse_month(str)
      Date.parse("#{str}-01")
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end

    def safe_date(str)
      Date.iso8601(str.to_s)
    rescue ArgumentError
      nil
    end

    def month_param(date)
      (date || Date.current).strftime("%Y-%m")
    end

    def booked_on?(property, date)
      property.bookings.blocking.where("check_in <= ? AND check_out > ?", date, date).exists?
    end

    # Blocks/opens every night in [from, to] inclusive, skipping already-booked dates.
    def apply_range(property, from, to, action)
      changed = 0
      (from..to).each do |date|
        next if date < Date.current
        next if booked_on?(property, date)

        av = property.availabilities.find_or_initialize_by(date: date)
        if action == "open"
          changed += 1 if av.persisted? && av.available == false && av.destroy
        else
          next if av.persisted? && av.available == false

          av.available = false
          changed += 1 if av.save
        end
      end
      changed
    end

    def load_calendar
      @grid_start = @month.beginning_of_month.beginning_of_week(:monday)
      @grid_end   = @month.end_of_month.end_of_week(:monday)

      # Map each visible date to the booking that covers it (check_in..check_out-1).
      @bookings_by_date = {}
      @property.bookings.blocking
               .where("check_in < ? AND check_out > ?", @grid_end + 1, @grid_start)
               .includes(:user).each do |booking|
        (booking.check_in...booking.check_out).each do |date|
          @bookings_by_date[date] = booking if date.between?(@grid_start, @grid_end)
        end
      end

      # Host-blocked dates + any custom per-night prices for the visible range.
      rows = @property.availabilities.where(date: @grid_start..@grid_end)
      @blocked = rows.select { |r| r.available == false }.map(&:date).to_set
      @custom_prices = rows.each_with_object({}) do |r, h|
        h[r.date] = r.custom_price if r.custom_price.present?
      end

      # This-month stats (only days within the actual month).
      month_days = (@month.beginning_of_month..@month.end_of_month)
      @booked_dates   = month_days.select { |d| @bookings_by_date[d]&.confirmed? }
      @pending_dates  = month_days.select { |d| @bookings_by_date[d]&.pending? }
      @blocked_in_month = month_days.count { |d| @blocked.include?(d) }
      @open_in_month  = month_days.count { |d| @bookings_by_date[d].nil? && !@blocked.include?(d) }
      @revenue_month  = @booked_dates.sum { |d| @custom_prices[d] || @property.price_per_night }
    end
  end
end
