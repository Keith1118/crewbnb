class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Whether guests can actually place bookings yet. Closed by default while we
  # finish pre-launch; flip on by setting ENV["BOOKINGS_OPEN"]="true" in Render.
  def bookings_open?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("BOOKINGS_OPEN", "false"))
  end
  helper_method :bookings_open?

  private

  # Guest and host accounts are separate entities: a host account books nothing,
  # and there is no switching between the two. Admins keep both sides so they can
  # act on a guest's behalf for support.
  def require_guest_account
    return if current_user.nil? || current_user.guest? || current_user.admin?

    redirect_to host_root_path,
                alert: "That's a guest area. Host accounts manage listings and bookings from here."
  end

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
