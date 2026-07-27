require "test_helper"

# Approving a request-to-book stay. Where the guest can be charged online, host
# approval must NOT confirm outright — otherwise the dates are blocked out and
# the stay happens with nothing ever collected. It goes to awaiting_payment and
# only becomes confirmed once the payment lands.
class BookingApprovalTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host, instant_book: false)
    @guest = create(:user, :business_verified)
    @booking = create(:booking, property: @property, user: @guest, status: :pending,
                      check_in: Date.current + 7, check_out: Date.current + 10)

    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  def approve_as_host
    sign_in @host
    patch host_booking_path(@booking), params: { booking: { status: "confirmed" } }
  end

  test "host approval asks the guest to pay instead of confirming" do
    approve_as_host

    assert @booking.reload.awaiting_payment?
    assert_not @booking.confirmed?
  end

  test "the guest is emailed a payment request on approval" do
    assert_enqueued_email_with BookingMailer, :payment_requested, args: [ @booking ] do
      approve_as_host
    end
  end

  test "an awaiting-payment booking still holds its dates against a rival booking" do
    approve_as_host

    clash = build(:booking, property: @property, user: create(:user, :business_verified),
                  check_in: Date.current + 8, check_out: Date.current + 9)

    assert_not clash.valid?
    assert_includes clash.errors[:base].join, "no longer available"
  end

  test "approval confirms outright when the host can't be paid online" do
    @host.update!(stripe_charges_enabled: false)

    approve_as_host

    assert @booking.reload.confirmed?
  end

  test "approval confirms outright when the booking is already paid" do
    create(:payment, booking: @booking, status: :succeeded)

    approve_as_host

    assert @booking.reload.confirmed?
  end

  test "the guest may still cancel while awaiting payment" do
    approve_as_host

    sign_in @guest
    patch booking_path(@booking), params: { booking: { status: "cancelled" } }

    assert @booking.reload.cancelled?
  end

  # The Pay Now button is hidden for an unapproved request, but the payment URL
  # is guessable — paying for a stay the host then rejects leaves us owing a
  # refund on a booking that never existed.
  test "a guest can't pay a request-to-book stay before the host approves it" do
    sign_in @guest

    get new_booking_payment_path(@booking)

    assert_redirected_to booking_path(@booking)
    assert_equal 0, @booking.payments.count
  end

  test "a guest can still pay an instant-book stay that's pending" do
    @property.update!(instant_book: true)
    sign_in @guest

    stub_class_method(Stripe::PaymentIntent, :create,
                      ->(*) { Struct.new(:id, :client_secret, :status, :amount).new("pi_x", "sec", "requires_payment_method", 0) }) do
      get new_booking_payment_path(@booking)
    end

    assert_response :success
  end

  test "the guest is offered the payment page while awaiting payment" do
    approve_as_host

    sign_in @guest
    get booking_path(@booking)

    assert_response :success
    assert_select "a[href=?]", new_booking_payment_path(@booking)
  end
end
