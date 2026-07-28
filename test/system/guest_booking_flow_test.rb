require "application_system_test_case"

# The full guest path in a real browser: sign up, find a property, pick dates,
# watch the price calculate live, and place the request.
class GuestBookingFlowTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :host)
    @property = create(:property, user: @host, title: "Edenderry Crew House",
                                  price_per_night: 80, max_guests: 4)
    @check_in  = Date.current + 30
    @check_out = Date.current + 33 # 3 nights
  end

  test "a new guest can sign up, verify their business, and request a booking" do
    # --- sign up -------------------------------------------------------------
    visit new_user_registration_path
    fill_in "First name", with: "Sean"
    fill_in "Last name",  with: "Murphy"
    fill_in "Email",      with: "sean@buildco.ie"
    fill_in "Password",              with: "password123!"
    fill_in "Password confirmation", with: "password123!"
    click_on "Sign Up"

    # Always settle the page before asserting on the database — Capybara returns
    # from click_on immediately, so a bare query can outrun the INSERT.
    assert_text(/signed up successfully/i, wait: 5)

    guest = User.find_by(email: "sean@buildco.ie")
    assert guest.present?, "signup should create the user"
    assert guest.guest?, "signup should default to a guest account"
    assert_no_js_errors

    # --- browse --------------------------------------------------------------
    visit properties_path
    assert_text "Edenderry Crew House", wait: 5
    click_on "Edenderry Crew House", match: :first
    assert_selector "h1", text: "Edenderry Crew House", wait: 5

    # --- pick dates and check the live price calculation ---------------------
    fill_in "Check-in",  with: @check_in
    fill_in "Check-out", with: @check_out
    fill_in "Guests",    with: 2

    # booking_calc_controller: 3 nights x EUR80 = EUR240
    assert_selector "[data-booking-calc-target='nights']", text: "3", wait: 5
    assert_selector "[data-booking-calc-target='total']",  text: "€240", wait: 5
    assert_no_js_errors

    # --- request the booking -------------------------------------------------
    click_on "Request to Book"

    # Guests must have a verified business before they can book.
    assert_text(/verify your company/i, wait: 5)

    verified = VatVerifier::Result.new(status: :verified, vat_number: "IE1234567X",
                                       name: "BuildCo Ltd", address: "Main St, Edenderry")
    stub_class_method(VatVerifier, :check, verified) do
      fill_in "Company name", with: "BuildCo Ltd"
      fill_in "VAT number",   with: "IE1234567X"
      click_on "Verify & continue"
      assert_text(/business verified/i, wait: 5)
    end

    assert guest.reload.business_verified?, "VAT verification should mark the business verified"

    # Verification drops the guest back into the booking they were making.
    assert_selector "h1", wait: 5
    click_on "Request to Book"
    assert_text(/request (is with the host|sent)|almost there/i, wait: 10)

    # --- the booking should now exist, in the right shape --------------------
    booking = guest.bookings.last
    assert booking.present?, "a booking should have been created"
    assert_equal @property, booking.property
    assert_equal @check_in,  booking.check_in
    assert_equal @check_out, booking.check_out
    assert_equal 3, booking.nights
    assert_equal 240, booking.total_price.to_i, "3 nights x EUR80 should total EUR240"
    assert booking.pending?, "a request-to-book stay starts pending"
    assert booking.invoice_reference.present?, "every booking gets an invoice reference"
    assert_no_js_errors
  end
end
