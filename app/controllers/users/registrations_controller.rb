class Users::RegistrationsController < Devise::RegistrationsController
  SELF_ASSIGNABLE_ROLES = %w[guest host].freeze

  rate_limit to: 5, within: 1.minute, only: :create,
             with: -> { redirect_to new_user_registration_path, alert: "Too many sign-up attempts. Please wait a minute and try again." }

  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name, :phone, :bio, :role, :avatar ])
  end

  # Users may never grant themselves a role beyond guest/host — admin is
  # assigned only from the console or by an existing admin.
  def sign_up_params
    super.tap do |params|
      params[:role] = "guest" unless SELF_ASSIGNABLE_ROLES.include?(params[:role])
    end
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name, :phone, :bio, :avatar ])
  end
end
