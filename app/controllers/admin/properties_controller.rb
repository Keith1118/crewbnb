module Admin
  class PropertiesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_property, only: [ :show, :edit, :update, :destroy, :sync_ical ]

    def index
      @pagy, @properties = pagy(
        Property.includes(:user).order(created_at: :desc),
        limit: 20
      )
    end

    def show
    end

    # Staff build (or finish building) a host's listing on their behalf.
    def new
      @property = Property.new
    end

    def create
      @property = Property.new(property_params)

      if @property.save
        redirect_to admin_property_path(@property), notice: "Listing created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @property.update(property_params)
        redirect_to admin_property_path(@property), notice: "Property updated."
      else
        # The moderation panel on #show only submits :status; the full editor
        # submits :title. Re-render whichever the request came from.
        render(params.dig(:property, :title) ? :edit : :show, status: :unprocessable_entity)
      end
    end

    def destroy
      @property.destroy
      redirect_to admin_properties_path, notice: "Property deleted."
    end

    def sync_ical
      result = @property.sync_ical!
      notice = result.ok? ? "Calendar synced — #{result.blocked_count} date(s) blocked." : "Sync failed: #{result.error}"
      redirect_to admin_property_path(@property), notice: notice
    end

    private

    def set_property
      @property = Property.find(params[:id])
    end

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end

    def property_params
      permitted = params.require(:property).permit(
        :user_id, :title, :description, :property_type, :address, :city, :country,
        :price_per_night, :weekday_discount, :bedrooms, :bathrooms, :max_guests, :status,
        :wifi_speed, :has_desk, :has_meeting_room, :has_parking, :has_printer,
        :instant_book, :bed_configuration, :house_rules, :check_in_time,
        :check_out_time, :nearby_attractions, :listing_url, :ical_url,
        images: [], amenity_ids: []
      )
      # Never move a listing to another owner once it exists.
      permitted.delete(:user_id) if @property&.persisted?
      permitted
    end
  end
end
