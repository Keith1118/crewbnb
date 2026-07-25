module Host
  class ApplicationsController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host

    def new
      @application = current_user.host_applications.build(applicant_type: :individual)
    end

    def create
      @application = current_user.host_applications.build(application_params)

      if @application.save
        HostApplicationMailer.submitted(@application).deliver_later
        redirect_to host_application_path(@application),
                    notice: "Thanks — your application is in. Our team will review it and set up your listing."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @application = current_user.host_applications.find(params[:id])
    end

    private

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end

    def application_params
      params.require(:host_application).permit(
        :applicant_type, :property_address, :listing_url, :ical_url,
        :company_name, :entity_type,
        proof_documents: [], business_documents: []
      )
    end
  end
end
