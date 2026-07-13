class Users::SessionsController < Devise::SessionsController
  rate_limit to: 10, within: 1.minute, only: :create,
             with: -> { redirect_to new_user_session_path, alert: "Too many sign-in attempts. Please wait a minute and try again." }
end
