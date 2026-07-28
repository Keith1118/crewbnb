require "application_system_test_case"

# The flows that had no browser coverage at all: host applications and their
# admin approval, Stripe Connect onboarding, reviews, invoices, favourites and
# search filtering.
class RemainingFlowsTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :host)
    @property = create(:property, user: @host, title: "Kildare Crew House",
                                  city: "Kildare", price_per_night: 95, max_guests: 6)
    @guest = create(:user, :business_verified)
  end

  # ----- host application + admin approval -----------------------------------

  test "a host can submit an application and an admin can approve it" do
    applicant = create(:user, :host)
    sign_in_as(applicant)

    visit new_host_application_path
    fill_field "host_application[property_address]", with: "12 Main Street, Kildare"
    fill_field "host_application[listing_url]", with: "https://airbnb.com/rooms/1"
    fill_field "host_application[ical_url]",   with: "https://airbnb.com/calendar/ical/1.ics"
    # Proof of control is mandatory, so a real file has to go up.
    attach_file "host_application[proof_documents][]", proof_file, make_visible: true
    submit_form_button("Submit application", expect: /received|submitted|review|thank/i)

    application = applicant.host_applications.last
    assert application.present?, "the application should be recorded"
    assert_equal "12 Main Street, Kildare", application.property_address

    sign_out_via_ui
    sign_in_as(create(:user, :admin))

    visit admin_host_applications_path
    assert_text(/12 Main Street|#{applicant.email}/i, wait: 10)

    visit admin_host_application_path(application)
    submit_form_button("Approve", expect: /approved/i)

    assert application.reload.approved?, "admin approval should mark it approved"
  end

  # ----- Stripe Connect onboarding -------------------------------------------

  test "a host without payouts is told to connect, and a ready host is not" do
    sign_in_as(@host)
    visit host_stripe_account_path
    assert_text(/connect (your )?payouts/i, wait: 10)
    assert_no_js_errors

    @host.update!(stripe_account_id: "acct_x", stripe_charges_enabled: true)
    visit host_stripe_account_path
    assert_no_text(/connect payouts/i, wait: 5)
  end

  test "a booking on a host who cannot receive payouts never asks for a card" do
    # @host has no Stripe account, so payable_online? is false and the stay is
    # settled off-platform rather than sending the guest to a dead card page.
    booking = create(:booking, property: @property, user: @guest,
                               check_in: Date.current + 20, check_out: Date.current + 22)

    assert_not booking.payable_online?
    sign_in_as(@guest)
    visit booking_path(booking)
    assert_no_selector "a[href='#{new_booking_payment_path(booking)}']"
  end

  # ----- reviews -------------------------------------------------------------

  test "a guest can review a completed stay and it shows on the listing" do
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                               check_in: Date.current + 5, check_out: Date.current + 7)
    booking.update_columns(status: Booking.statuses[:completed],
                           check_in: Date.current - 10, check_out: Date.current - 8)

    sign_in_as(@guest)
    visit new_booking_review_path(booking)

    choose_rating 5
    fill_field "review[comment]", with: "Spotless, great parking, slept four of us easily."
    submit_form_button("Submit", expect: /thank|review/i)

    review = booking.reload.review
    assert review.present?, "the review should be saved"
    assert_equal 5, review.rating

    visit property_path(@property)
    assert_text "Spotless, great parking", wait: 10
    assert_equal 5.0, @property.reload.average_rating
  end

  test "a stay that has not happened cannot be reviewed" do
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                               check_in: Date.current + 20, check_out: Date.current + 22)

    sign_in_as(@guest)
    visit new_booking_review_path(booking)

    assert_text(/once you've completed a stay/i, wait: 10)
    assert_nil booking.reload.review
  end

  # ----- invoices ------------------------------------------------------------

  test "the invoice is hidden until the stay has happened, then available to both sides" do
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                               check_in: Date.current + 20, check_out: Date.current + 22)

    sign_in_as(@guest)
    visit invoice_booking_path(booking)
    assert_text(/available after the stay/i, wait: 10)

    # Move the stay into the past — now it is a real invoice.
    booking.update_columns(check_in: Date.current - 5, check_out: Date.current - 3)

    visit invoice_booking_path(booking)
    assert_text booking.invoice_reference, wait: 10
    assert_text "Kildare Crew House"

    # The host issues it, so they must be able to see it too. Leave the invoice
    # layout first — it has no nav, so no sign-out form to submit.
    visit root_path
    sign_out_via_ui
    sign_in_as(@host)
    visit invoice_booking_path(booking)
    assert_text booking.invoice_reference, wait: 10
  end

  test "a stranger cannot read someone else's invoice" do
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                               check_in: Date.current + 20, check_out: Date.current + 22)
    booking.update_columns(check_in: Date.current - 5, check_out: Date.current - 3)

    sign_in_as(create(:user, :business_verified))
    visit invoice_booking_path(booking)

    assert_no_text booking.invoice_reference, wait: 5
  end

  # ----- favourites ----------------------------------------------------------

  test "a guest can favourite a listing and find it again" do
    sign_in_as(@guest)
    visit property_path(@property)

    submit_form_button("Save", expect: /added to your favorites/i)
    assert_equal 1, @guest.favorites.count

    visit properties_path(favorites: true)
    assert_text "Kildare Crew House", wait: 10
  end

  # ----- search --------------------------------------------------------------

  test "search filters narrow the listing" do
    create(:property, user: @host, title: "Galway Crew Apartment", city: "Galway",
                      price_per_night: 200, max_guests: 2, property_type: "apartment")

    visit properties_path(query: "Kildare")
    assert_text "Kildare Crew House", wait: 10
    assert_no_text "Galway Crew Apartment"

    visit properties_path(max_price: 100)
    assert_text "Kildare Crew House", wait: 10
    assert_no_text "Galway Crew Apartment"

    visit properties_path(guests: 5)
    assert_text "Kildare Crew House", wait: 10
    assert_no_text "Galway Crew Apartment"

    visit properties_path(property_type: "apartment")
    assert_text "Galway Crew Apartment", wait: 10
    assert_no_text "Kildare Crew House"
    assert_no_js_errors
  end

  test "dates already booked drop the listing out of a date search" do
    create(:booking, property: @property, user: @guest, status: :confirmed,
                     check_in: Date.current + 30, check_out: Date.current + 33)

    visit properties_path(check_in: (Date.current + 31).to_s, check_out: (Date.current + 32).to_s)
    assert_no_text "Kildare Crew House", wait: 10
  end

  private

  # A small real file for the mandatory proof-of-control upload.
  def proof_file
    path = Rails.root.join("tmp", "proof_of_control.txt")
    File.write(path, "utility bill") unless File.exist?(path)
    path
  end

  # The rating control is a set of radio inputs, often visually hidden behind
  # star labels.
  def choose_rating(value)
    page.execute_script(<<~JS)
      (() => {
        const input = document.querySelector("input[name='review[rating]'][value='#{value}']");
        input.checked = true;
        input.dispatchEvent(new Event("change", { bubbles: true }));
      })()
    JS
  end
end
