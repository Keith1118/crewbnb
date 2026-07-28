require "application_system_test_case"

# Sign-in edge cases: a wrong password, the full password-reset round trip, and
# remember-me actually surviving the browser session ending.
class AuthEdgeCasesTest < ApplicationSystemTestCase
  setup do
    @user = create(:user, :business_verified, email: "crew@buildco.ie")
  end

  test "a wrong password is refused and says so" do
    visit new_user_session_path
    fill_field "Email", with: @user.email
    fill_field "Password", with: "definitely-not-it"
    submit_form_button("Sign In", expect: /invalid email or password/i)

    assert_current_path new_user_session_path
  end

  test "an unknown email is refused without revealing whether it exists" do
    visit new_user_session_path
    fill_field "Email", with: "nobody@nowhere.ie"
    fill_field "Password", with: "password123!"
    submit_form_button("Sign In", expect: /invalid email or password/i)
  end

  test "a guest can reset their password and sign in with the new one" do
    visit new_user_password_path
    fill_field "Email", with: @user.email

    perform_enqueued_jobs do
      submit_form_button("Send Reset Instructions", expect: /receive an email|reset/i)
    end

    mail = ActionMailer::Base.deliveries.last
    assert mail.present?, "a reset email should have been sent"
    assert_includes mail.to, @user.email

    token = mail.body.encoded[/reset_password_token=([^"&\s\\]+)/, 1]
    assert token.present?, "the reset email must carry a usable token"

    visit edit_user_password_path(reset_password_token: token)
    fill_field "New password", with: "brandNewPass1!"
    fill_field "Password confirmation", with: "brandNewPass1!"
    submit_form_button("Change My Password", expect: /password has been changed|signed in/i)

    # The new password must work, and the old one must not.
    sign_out_via_ui
    visit new_user_session_path
    fill_field "Email", with: @user.email
    fill_field "Password", with: "password123!"
    submit_form_button("Sign In", expect: /invalid email or password/i)

    sign_in_as(@user, password: "brandNewPass1!")
    assert_text(/signed in successfully/i, wait: 10)
  end

  test "a used reset token cannot be replayed" do
    token = @user.send_reset_password_instructions

    visit edit_user_password_path(reset_password_token: token)
    fill_field "New password", with: "firstChange1!"
    fill_field "Password confirmation", with: "firstChange1!"
    submit_form_button("Change My Password", expect: /password has been changed|signed in/i)

    sign_out_via_ui

    # Same token again — Devise clears it on use, so this must be refused.
    visit edit_user_password_path(reset_password_token: token)
    fill_field "New password", with: "secondChange1!"
    fill_field "Password confirmation", with: "secondChange1!"
    submit_form_button("Change My Password", expect: /invalid|expired|reset password token/i)

    assert @user.reload.valid_password?("firstChange1!"),
           "a replayed token must not change the password again"
  end

  test "remember me keeps the guest signed in after the session cookie is gone" do
    visit new_user_session_path
    fill_field "Email", with: @user.email
    fill_field "Password", with: "password123!"
    check "Remember me"
    submit_form_button("Sign In", expect: /signed in successfully/i)

    assert @user.reload.remember_created_at.present?,
           "ticking remember me should persist a remember token"

    # Drop only the session cookie, the way closing the browser does. The
    # remember_user_token cookie should sign them straight back in.
    page.driver.browser.manage.delete_cookie("_crewbase_session")
    page.driver.browser.manage.all_cookies.each do |c|
      page.driver.browser.manage.delete_cookie(c[:name]) if c[:name].match?(/session/i)
    end

    visit bookings_path
    assert_no_text(/log in|sign in to your crewbase account/i, wait: 5)
    assert_current_path bookings_path
  end

  test "signing out without remember me does not leave a way back in" do
    sign_in_as(@user)
    sign_out_via_ui

    visit bookings_path
    assert_current_path new_user_session_path
  end
end
