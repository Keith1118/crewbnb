module Admin
  class PropertiesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_property, only: [:show, :update, :destroy]

    def index
      @pagy, @properties = pagy(
        Property.includes(:user).order(created_at: :desc),
        limit: 20
      )
    end

    def show
    end

    def update
      if @property.update(property_params)
        redirect_to admin_property_path(@property), notice: "Property updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @property.destroy
      redirect_to admin_properties_path, notice: "Property deleted."
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
      params.require(:property).permit(:status)
    end
  end
end
