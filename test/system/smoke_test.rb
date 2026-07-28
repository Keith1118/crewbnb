require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "home page renders in a real browser" do
    visit root_path

    assert_selector "h1", wait: 5
    assert_no_js_errors
  end

  test "an existing user can sign in through the form" do
    user = create(:user, :business_verified)

    sign_in_as(user)

    assert_text(/signed in|dashboard|bookings/i, wait: 5)
    assert_no_js_errors
  end
end
