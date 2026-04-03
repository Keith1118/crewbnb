module Admin
  class ReviewsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @pagy, @reviews = pagy(
        Review.includes(:reviewer, :reviewable, :booking).order(created_at: :desc),
        limit: 20
      )
    end

    def destroy
      @review = Review.find(params[:id])
      @review.destroy
      redirect_to admin_reviews_path, notice: "Review deleted."
    end

    private

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end
  end
end
