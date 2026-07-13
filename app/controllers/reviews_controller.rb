class ReviewsController < ApplicationController
  before_action :authenticate_user!

  def new
    if params[:booking_id].present?
      @booking = current_user.bookings.find(params[:booking_id])
      @property = @booking.property
    else
      @property = Property.find(params[:property_id])
      @booking = current_user.bookings.where(property: @property).completed.last
    end

    unless @booking&.completed?
      redirect_to @property, alert: "You can review a property once you've completed a stay there."
      return
    end

    @review = Review.new
  end

  def create
    if params[:booking_id].present?
      @booking = current_user.bookings.find(params[:booking_id])
      @property = @booking.property
    else
      @property = Property.find(params[:property_id])
      @booking = current_user.bookings.where(property: @property).completed.last
    end

    unless @booking&.completed?
      redirect_to @property, alert: "You can review a property once you've completed a stay there."
      return
    end

    @review = Review.new(review_params)
    @review.reviewer = current_user
    @review.booking = @booking
    @review.reviewable = @property
    authorize @review

    if @review.save
      redirect_to @property, notice: "Review submitted successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def review_params
    params.require(:review).permit(:rating, :comment)
  end
end
