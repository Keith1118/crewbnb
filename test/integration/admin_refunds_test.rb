require "test_helper"

# Refunding a Connect destination charge. The money sat in the host's account
# with our commission taken as an application fee, so both have to be reversed —
# otherwise Crewbase refunds the guest out of its own pocket.
class AdminRefundsTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :stripe_ready)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified)
    @booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                      check_in: Date.current + 7, check_out: Date.current + 10)
    @payment = create(:payment, booking: @booking, status: :succeeded,
                      amount: 400, stripe_payment_intent_id: "pi_123")

    sign_in create(:user, :admin)

    @orig_key = Stripe.api_key
    Stripe.api_key = "sk_test_x"
  end

  teardown { Stripe.api_key = @orig_key }

  def stub_refund(&block)
    @captured = nil
    stub_class_method(Stripe::Refund, :create, ->(args) { @captured = args; Struct.new(:id).new("re_1") }, &block)
  end

  test "a full refund reverses the host transfer and the application fee" do
    stub_refund do
      post refund_admin_payment_path(@payment)
    end

    assert_equal 40_000, @captured[:amount]
    assert @captured[:reverse_transfer], "host's payout must be pulled back"
    assert @captured[:refund_application_fee], "Crewbase's commission must be returned too"
    assert @payment.reload.refunded?
    assert_equal 400, @payment.refunded_amount
  end

  test "a partial refund leaves the payment succeeded and tracks the balance" do
    stub_refund do
      post refund_admin_payment_path(@payment), params: { amount: "150.00" }
    end

    assert_equal 15_000, @captured[:amount]
    assert @payment.reload.succeeded?
    assert_equal 150, @payment.refunded_amount
  end

  test "partial refunds accumulate and flip to refunded once fully returned" do
    stub_refund { post refund_admin_payment_path(@payment), params: { amount: "150.00" } }
    stub_refund { post refund_admin_payment_path(@payment), params: { amount: "250.00" } }

    assert_equal 400, @payment.reload.refunded_amount
    assert @payment.refunded?
  end

  test "refunding more than remains is rejected before reaching Stripe" do
    called = false
    stub_class_method(Stripe::Refund, :create, ->(*) { called = true }) do
      post refund_admin_payment_path(@payment), params: { amount: "500.00" }
    end

    assert_not called, "must not call Stripe with an over-refund"
    assert_equal 0, @payment.reload.refunded_amount.to_d
    assert_match(/still refundable/, flash[:alert])
  end

  test "a Stripe failure surfaces rather than marking the payment refunded" do
    stub_class_method(Stripe::Refund, :create, ->(*) { raise Stripe::StripeError.new("charge already refunded") }) do
      post refund_admin_payment_path(@payment)
    end

    assert @payment.reload.succeeded?
    assert_match(/charge already refunded/, flash[:alert])
  end

  test "the booking page offers a refund form for a succeeded payment" do
    get admin_booking_path(@booking)

    assert_response :success
    assert_select "form[action=?]", refund_admin_payment_path(@payment)
  end

  test "non-admins can't refund" do
    sign_in @guest

    stub_refund { post refund_admin_payment_path(@payment) }

    assert_redirected_to root_path
    assert @payment.reload.succeeded?
  end
end
