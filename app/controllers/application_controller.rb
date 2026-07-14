class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # After sign-in, send hosts/admins straight to their management area (their
  # "extranet"), unless Devise saved a page they were originally trying to reach.
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || default_path_for(resource)
  end

  def default_path_for(user)
    return admin_root_path if user.respond_to?(:admin?) && user.admin?
    return host_root_path if user.respond_to?(:host?) && user.host?

    root_path
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end
end
