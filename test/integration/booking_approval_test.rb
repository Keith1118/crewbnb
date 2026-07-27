require "test_helper"

# Approving a request-to-book stay. The guest's card was saved when they booked,
# so approval doesn't ask them for anything: it confirms, and either charges now
# (if check-in is already inside the charge window) or leaves it to the daily job.
class BookingApprovalTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host, instant_book: false)
    @guest = create(:user, :business_verified, stripe_customer_id: "cus_1")

    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  # Far enough out that the charge date hasn't arrived.
  def distant_booking
    create(:booking, property: @property, user: @guest, status: :pending,
           stripe_payment_method_id: "pm_1",
           check_in: Date.current + 40, check_out: Date.current + 43)
  end

  # Inside CHARGE_LEAD_TIME, so approving should take the money at once.
  def imminent_booking
    create(:booking, property: @property, user: @guest, status: :pending,
           stripe_payment_method_id: "pm_1",
           check_in: Date.current + 3, check_out: Date.current + 5)
  end

  def approve(booking)
    sign_in @host
    patch host_booking_path(booking), params: { booking: { status: "confirmed" } }
  end

  def succeeding_intent
    Struct.new(:id, :status).new("pi_ok", "succeeded")
  end

  test "approving a distant stay confirms it without charging" do
    booking = distant_booking
    charged = false

    stub_class_method(Stripe::PaymentIntent, :create, ->(*) { charged = true; succeeding_intent }) do
      approve(booking)
    end

    assert booking.reload.confirmed?
    assert_not charged, "must not charge before the charge date"
    assert_not booking.paid?
  end

  test "approving a stay inside the charge window takes payment immediately" do
    booking = imminent_booking
    captured = nil

    stub_class_method(Stripe::PaymentIntent, :create, ->(args) { captured = args; succeeding_intent }) do
      approve(booking)
    end

    assert booking.reload.confirmed?
    assert booking.paid?
    assert_equal "pm_1", captured[:payment_method]
    assert captured[:off_session], "a charge with no guest present must be off-session"
    assert_equal @host.stripe_account_id, captured.dig(:transfer_data, :destination)
    assert_equal (booking.commission_amount * 100).to_i, captured[:application_fee_amount]
  end

  test "a declined card moves the stay to awaiting payment with a deadline" do
    booking = imminent_booking

    stub_class_method(Stripe::PaymentIntent, :create, ->(*) { raise Stripe::CardError.new("card declined", nil) }) do
      approve(booking)
    end

    booking.reload
    assert booking.awaiting_payment?
    assert_not_nil booking.payment_due_by
    assert_not_nil booking.charge_failed_at
    assert booking.payment_due_by > Time.current
  end

  test "a declined card emails the guest a pay-by-hand link" do
    booking = imminent_booking

    assert_enqueued_email_with BookingMailer, :payment_failed, args: [ booking ] do
      stub_class_method(Stripe::PaymentIntent, :create, ->(*) { raise Stripe::CardError.new("declined", nil) }) do
        approve(booking)
      end
    end
  end

  test "approval confirms outright when no card was ever saved" do
    booking = create(:booking, property: @property, user: @guest, status: :pending,
                     check_in: Date.current + 3, check_out: Date.current + 5)

    approve(booking)

    assert booking.reload.confirmed?
  end

  test "an approved stay still holds its dates against a rival booking" do
    booking = distant_booking
    approve(booking)

    clash = build(:booking, property: @property, user: create(:user, :business_verified),
                  check_in: booking.check_in + 1, check_out: booking.check_out - 1)

    assert_not clash.valid?
    assert_includes clash.errors[:base].join, "no longer available"
  end

  # The Pay Now button is hidden for an unapproved request, but the URL is
  # guessable — paying for a stay the host then rejects leaves us owing a refund.
  test "a guest can't pay a request-to-book stay before the host approves it" do
    booking = distant_booking
    sign_in @guest

    get new_booking_payment_path(booking)

    assert_redirected_to booking_path(booking)
    assert_equal 0, booking.payments.count
  end
end
