require "application_system_test_case"

# Card capture through the real Stripe Payment Element, then host approval.
#
# These hit Stripe's live TEST mode: js.stripe.com renders the Element and the
# SetupIntent is real. Nothing is charged — a SetupIntent only stores a card.
class BookingPaymentFlowTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host, title: "Portlaoise Crew House",
                                  price_per_night: 100, max_guests: 4)
    @guest = create(:user, :business_verified)
    @check_in  = Date.current + 30
    @check_out = Date.current + 32 # 2 nights = EUR200
  end

  test "the card form mounts when reached by Turbo redirect from the booking form" do
    # Regression test. Turbo swaps the body and connects Stimulus controllers
    # before the <script src="js.stripe.com"> it copies into <head> has run, so
    # the controller used to find Stripe undefined, give up, and leave every
    # guest on a dead card form that only a manual refresh could fix.
    sign_in_as(@guest)
    assert_text(/signed in/i, wait: 5)

    visit property_path(@property)
    fill_in "Check-in",  with: @check_in
    fill_in "Check-out", with: @check_out
    submit_form_button("Request to Book", expect: /hold your dates/i)

    assert page.has_selector?("#payment-element iframe", wait: 25),
           "the Stripe Payment Element never mounted"
    assert_equal "", payment_error_text,
                 "the card form reported an error instead of mounting"
    assert_not page.evaluate_script(
      "document.querySelector('[data-payment-form-target=submitButton]').disabled"
    ), "the submit button was left disabled"
  end

  test "guest saves a card through the Stripe Payment Element and the host approves" do
    sign_in_as(@guest)
    assert_text(/signed in/i, wait: 5)

    visit property_path(@property)
    fill_in "Check-in",  with: @check_in
    fill_in "Check-out", with: @check_out
    submit_form_button("Request to Book", expect: /hold your dates/i)

    booking = @guest.bookings.last
    assert booking.present?
    assert_equal 200, booking.total_price.to_i
    assert booking.pending?
    assert_nil booking.stripe_payment_method_id, "no card saved yet"

    # The page must promise no charge today, and name the real charge date.
    assert_text "You won't be charged today"
    assert_text booking.charge_on.strftime("%-d %B %Y")

    # Typing into the Payment Element itself is not drivable: Stripe hardens its
    # cross-origin iframe against synthetic input, so fill_in / send_keys / slow
    # per-character typing all leave the fields empty and confirmSetup reports
    # "Your card number is incomplete". The mount is covered by the test above;
    # here we confirm the very same SetupIntent through Stripe's test API and
    # then re-enter the browser at the exact URL Stripe would have redirected to.
    confirm_setup_intent_out_of_band(booking)

    booking.reload
    assert booking.stripe_payment_method_id.present?,
           "the saved card should be stored on the booking"
    assert booking.pending?, "a non-instant-book stay waits for the host"

    # --- host approves -------------------------------------------------------
    sign_out_via_ui
    sign_in_as(@host)
    assert_text(/signed in/i, wait: 5)

    visit host_booking_path(booking)

    # The host sees their real payout before approving: total less 7.5%.
    assert_text "€185.00"

    submit_form_button("Approve Booking", expect: /approved|confirmed/i)

    booking.reload
    assert booking.confirmed?, "host approval should confirm the booking"
    # Check-in is 30 days out, so the charge is still in the future.
    assert_not booking.paid?, "nothing is charged until the T-10 job runs"
    assert_equal @check_in - Booking::CHARGE_LEAD_TIME, booking.charge_on
  end

  private

  def payment_error_text
    page.evaluate_script("document.getElementById('payment-errors').textContent").to_s.strip
  end

  # Confirms the real SetupIntent the page is holding, using Stripe's test card
  # token, then returns to the browser at Stripe's own return_url. Everything
  # after this point — the complete action, the booking state, host approval —
  # is still exercised through the real app.
  def confirm_setup_intent_out_of_band(booking)
    client_secret = page.evaluate_script(
      "document.querySelector('[data-payment-form-client-secret-value]')" \
      ".dataset.paymentFormClientSecretValue"
    )
    assert client_secret.present?, "the card page never received a SetupIntent client secret"

    setup_intent_id = client_secret.split("_secret_").first
    # The intent enables redirect-capable methods (Klarna), so Stripe requires a
    # return_url even for a card confirmation — the same one the page passes.
    intent = Stripe::SetupIntent.confirm(
      setup_intent_id,
      payment_method: "pm_card_visa",
      return_url: complete_booking_card_url(booking, host: Capybara.current_session.server.host,
                                                     port: Capybara.current_session.server.port)
    )
    assert_equal "succeeded", intent.status, "Stripe would not confirm the SetupIntent"

    visit complete_booking_card_path(booking, setup_intent: setup_intent_id)
  end
end
