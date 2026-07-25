module Admin
  class HostApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_application, only: [ :show, :approve, :reject ]

    def index
      # Pending first (enum order), then newest within each status.
      @pagy, @applications = pagy(
        HostApplication.includes(:user, :property).order(:status, created_at: :desc),
        limit: 20
      )
    end

    def show
    end

    # Approve the application and spin up a draft listing owned by the applicant,
    # pre-filled with what they submitted. Staff then complete the listing; the
    # host can edit it afterwards.
    def approve
      unless @application.pending?
        redirect_to admin_host_application_path(@application), alert: "This application has already been reviewed."
        return
      end

      property = nil
      HostApplication.transaction do
        property = build_draft_property(@application)
        property.save!(validate: false)

        if @application.company?
          @application.user.update!(
            company_name: @application.company_name,
            business_verified_at: Time.current
          )
        end

        @application.update!(
          status: :approved,
          property: property,
          reviewed_at: Time.current,
          reviewed_by: current_user,
          review_notes: params[:review_notes].presence
        )
      end

      HostApplicationMailer.approved(@application).deliver_later
      redirect_to edit_admin_property_path(property),
                  notice: "Approved. Finish building the listing below, then publish it."
    end

    def reject
      @application.update!(
        status: :rejected,
        reviewed_at: Time.current,
        reviewed_by: current_user,
        review_notes: params[:review_notes].presence
      )
      HostApplicationMailer.rejected(@application).deliver_later
      redirect_to admin_host_applications_path, notice: "Application rejected and the applicant notified."
    end

    private

    def set_application
      @application = HostApplication.find(params[:id])
    end

    def build_draft_property(application)
      application.user.properties.build(
        status: :draft,
        title: "Draft — #{application.property_address}",
        address: application.property_address,
        listing_url: application.listing_url,
        ical_url: application.ical_url
      )
    end

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end
  end
end
