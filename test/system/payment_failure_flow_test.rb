require "application_system_test_case"

# What happens when the automatic charge is refused: the booking moves to
# awaiting_payment and the guest gets a pay-by-hand page. That page runs the
# same payment-form controller as card capture, in "payment" mode rather than
# "setup", so it needs the same proof that the Element actually mounts.
class PaymentFailureFlowTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host, title: "Tullamore Crew House",
                                  price_per_night: 100)
    @guest = create(:user, :business_verified, stripe_customer_id: "cus_1")
    @booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                                stripe_payment_method_id: "pm_1",
                                check_in: Date.current + 5, check_out: Date.current + 7)
  end

  test "a declined card moves the booking to awaiting_payment with a deadline" do
    assert @booking.charge_due?, "a stay 5 days out is inside the charge window"

    decline = ->(*) { raise Stripe::CardError.new("Your card was declined.", nil) }
    stub_class_method(Stripe::PaymentIntent, :create, decline) do
      ChargeDueBookingsJob.perform_now
    end

    @booking.reload
    assert @booking.awaiting_payment?, "a refused card must not silently confirm"
    assert @booking.charge_failed_at.present?
    assert @booking.payment_due_by.present?, "the guest needs a deadline to pay by hand"
    assert_in_delta Booking::MANUAL_PAYMENT_GRACE.from_now.to_i, @booking.payment_due_by.to_i, 60
    assert_not @booking.paid?
  end

  test "the guest can reach the pay-by-hand page and its card form mounts" do
    @booking.update!(status: :awaiting_payment, charge_failed_at: Time.current,
                     payment_due_by: Booking::MANUAL_PAYMENT_GRACE.from_now)

    sign_in_as(@guest)
    visit booking_path(@booking)

    # Reached by a Turbo visit — the same navigation that broke card capture.
    click_safely "a[href='#{new_booking_payment_path(@booking)}']",
                 expect_path: new_booking_payment_path(@booking)

    assert page.has_selector?("#payment-element iframe", wait: 25),
           "the pay-by-hand Payment Element never mounted"
    assert_equal "", page.evaluate_script(
      "document.getElementById('payment-errors').textContent"
    ).to_s.strip, "the card form reported an error instead of mounting"
    assert_no_js_errors
  end

  test "refreshing the payment page reuses the intent instead of stacking up payments" do
    @booking.update!(status: :awaiting_payment, payment_due_by: 2.days.from_now)

    sign_in_as(@guest)
    visit new_booking_payment_path(@booking)
    assert_text(/complete payment/i, wait: 15)
    first_count = @booking.payments.count

    visit new_booking_payment_path(@booking)
    assert_text(/complete payment/i, wait: 15)

    assert_equal first_count, @booking.reload.payments.count,
                 "reloading the payment page must not create a second payment record"
  end

  test "a stay still waiting on the host cannot be paid through a guessed URL" do
    pending_booking = create(:booking, property: @property, user: @guest, status: :pending,
                                       check_in: Date.current + 20, check_out: Date.current + 22)

    sign_in_as(@guest)
    visit new_booking_payment_path(pending_booking)

    assert_text(/still with the host/i, wait: 10)
    assert_equal 0, pending_booking.payments.count
  end

  test "a cancelled booking cannot be paid" do
    @booking.update!(status: :cancelled)

    sign_in_as(@guest)
    visit new_booking_payment_path(@booking)

    assert_text(/cancelled and can't be paid/i, wait: 10)
  end

  test "the release job cancels a stay the guest never paid for" do
    @booking.update!(status: :awaiting_payment, charge_failed_at: 4.days.ago,
                     payment_due_by: 1.hour.ago)

    ReleaseUnpaidBookingsJob.perform_now

    assert @booking.reload.cancelled?, "an expired grace period must free the dates"
    assert @property.available_between?(@booking.check_in, @booking.check_out),
           "the released dates should be bookable again"
  end
end
