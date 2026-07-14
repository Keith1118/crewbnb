module Host
  class PropertiesController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host
    before_action :set_property, only: [ :show, :edit, :update, :destroy ]

    def index
      @pagy, @properties = pagy(
        current_user.properties.order(created_at: :desc),
        limit: 10
      )
    end

    def show
    end

    def new
      @property = current_user.properties.build
    end

    def create
      @property = current_user.properties.build(property_params)

      if @property.save
        redirect_to host_property_path(@property), notice: "Property created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @property.update(property_params)
        redirect_to host_property_path(@property), notice: "Property updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @property.destroy
      redirect_to host_properties_path, notice: "Property deleted."
    end

    private

    def set_property
      @property = current_user.properties.find(params[:id])
    end

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end

    def property_params
      params.require(:property).permit(
        :title, :description, :property_type, :address, :city, :country,
        :price_per_night, :bedrooms, :bathrooms, :max_guests, :status,
        :wifi_speed, :has_desk, :has_meeting_room, :has_parking, :has_printer,
        :instant_book, :bed_configuration, :house_rules, :check_in_time,
        :check_out_time, :nearby_attractions, images: [],
        amenity_ids: []
      )
    end
  end
end
