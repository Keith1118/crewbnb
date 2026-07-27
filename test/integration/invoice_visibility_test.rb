require "test_helper"

# An invoice before the stay is a quote for something that might still be
# cancelled. It appears only once checkout has passed — the same moment the
# emailed copy goes out.
class InvoiceVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :host)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified)
  end

  def future_stay
    create(:booking, property: @property, user: @guest, status: :confirmed,
           check_in: Date.current + 10, check_out: Date.current + 12)
  end

  # check_in_not_in_past blocks creating one directly, so move it back after.
  def finished_stay
    booking = future_stay
    booking.update_columns(check_in: Date.current - 4, check_out: Date.current - 2)
    booking
  end

  test "a guest can't open the invoice before the stay" do
    booking = future_stay
    sign_in @guest

    get invoice_booking_path(booking)

    assert_redirected_to booking_path(booking)
  end

  test "a guest can open the invoice after the stay" do
    booking = finished_stay
    sign_in @guest

    get invoice_booking_path(booking)

    assert_response :success
  end

  test "the invoice link is hidden on the booking page before the stay" do
    booking = future_stay
    sign_in @guest

    get booking_path(booking)

    assert_select "a[href=?]", invoice_booking_path(booking), count: 0
  end

  test "the invoice link appears on the booking page after the stay" do
    booking = finished_stay
    sign_in @guest

    get booking_path(booking)

    assert_select "a[href=?]", invoice_booking_path(booking)
  end

  # The invoice is issued BY the host, so they reach it despite the guest/host
  # split — but no earlier than the guest does.
  test "a host can't open the invoice before the stay either" do
    booking = future_stay
    sign_in @host

    get invoice_booking_path(booking)

    assert_redirected_to host_booking_path(booking)
  end

  test "a host can open the invoice after the stay" do
    booking = finished_stay
    sign_in @host

    get invoice_booking_path(booking)

    assert_response :success
  end

  # Admins can pull it early for support.
  test "an admin can open the invoice before the stay" do
    booking = future_stay
    sign_in create(:user, :admin)

    get invoice_booking_path(booking)

    assert_response :success
  end

  test "a cancelled stay is never invoiceable" do
    booking = finished_stay
    booking.update!(status: :cancelled)

    assert_not booking.invoiceable?
  end
end
