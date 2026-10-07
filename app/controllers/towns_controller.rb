# Landing pages for "contractor accommodation in <town>" — see Town.
class TownsController < ApplicationController
  def show
    @town = Town.find(params[:id])
    @properties = @town.properties.with_attached_images.includes(:reviews).order(:price_per_night, :id).to_a
    raise ActiveRecord::RecordNotFound, "No listings in #{@town.name}" if @properties.empty?

    @other_towns = Town.with_listings - [ @town ]
  end
end
