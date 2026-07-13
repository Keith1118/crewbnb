class Users::PasswordsController < Devise::PasswordsController
  rate_limit to: 5, within: 1.minute, only: :create,
             with: -> { redirect_to new_user_password_path, alert: "Too many password reset requests. Please wait a minute and try again." }
end
