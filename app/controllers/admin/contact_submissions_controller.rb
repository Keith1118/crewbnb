module Admin
  class ContactSubmissionsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @pagy, @contact_submissions = pagy(
        ContactSubmission.order(created_at: :desc),
        limit: 20
      )
    end

    def show
      @contact_submission = ContactSubmission.find(params[:id])
      @contact_submission.read! if @contact_submission.pending?
    end

    def destroy
      @contact_submission = ContactSubmission.find(params[:id])
      @contact_submission.destroy
      redirect_to admin_contact_submissions_path, notice: "Submission deleted."
    end

    private

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end
  end
end
