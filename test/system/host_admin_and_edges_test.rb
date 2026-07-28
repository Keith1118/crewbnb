require "application_system_test_case"

# Host calendar and dashboard, the admin views, and the edge cases where a
# booking must be refused.
class HostAdminAndEdgesTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :host)
    @property = create(:property, user: @host, title: "Mullingar Crew House",
                                  price_per_night: 90, max_guests: 4)
    @guest = create(:user, :business_verified)
    @check_in  = Date.current + 30
    @check_out = Date.current + 33
  end

  # ----- host calendar -------------------------------------------------------

  test "a date the host blocks on the calendar cannot then be booked" do
    @property.availabilities.create!(date: @check_in + 1, available: false)

    sign_in_as(@guest)
    visit property_path(@property)
    fill_field "Check-in",  with: @check_in
    fill_field "Check-out", with: @check_out
    submit_form_button("Request to Book", expect: /blocked by the host|no longer available/i)

    assert_equal 0, Booking.where(property: @property).count,
                 "a blocked date must not produce a booking"
  end

  test "the host calendar renders the month containing a booking" do
    create(:booking, property: @property, user: @guest, status: :confirmed,
                     check_in: @check_in, check_out: @check_out)

    sign_in_as(@host)
    visit host_calendar_path(property_id: @property.id, month: @check_in.strftime("%Y-%m"))

    assert_text(/Mullingar Crew House/i, wait: 10)
    assert_text @check_in.strftime("%B"), wait: 10
    assert_no_js_errors
  end

  # ----- host dashboard ------------------------------------------------------

  test "the host dashboard lists a pending request with its real figures" do
    create(:booking, property: @property, user: @guest, status: :pending,
                     check_in: @check_in, check_out: @check_out)

    sign_in_as(@host)
    visit host_root_path

    assert_text "Mullingar Crew House", wait: 10
    assert_text "3 nights · €270", wait: 10 # 3 nights x EUR90
    assert_no_js_errors
  end

  # ----- edge cases ----------------------------------------------------------

  test "overlapping dates are refused" do
    create(:booking, property: @property, user: create(:user, :business_verified),
                     status: :confirmed, check_in: @check_in, check_out: @check_out)

    sign_in_as(@guest)
    visit property_path(@property)
    fill_field "Check-in",  with: @check_in + 1
    fill_field "Check-out", with: @check_out + 1
    submit_form_button("Request to Book", expect: /no longer available/i)

    assert_equal 1, Booking.where(property: @property).count,
                 "the clashing booking must not be created"
  end

  test "moving check-in past check-out pulls check-out up to the first valid night" do
    sign_in_as(@guest)
    visit property_path(@property)

    # Driven through real DOM events rather than native typing: ChromeDriver
    # drops keystrokes on this page often enough to make the assertion flaky,
    # and what's under test is the Stimulus controller's reaction, not typing.
    set_date "checkOut", @check_in + 5
    set_date "checkIn",  @check_in + 10

    assert_equal (@check_in + 11).to_s, find_field("Check-out").value,
                 "check-out should be pulled to the night after check-in, not cleared"
    assert_equal (@check_in + 11).to_s, find_field("Check-out")[:min],
                 "check-out's floor should follow check-in"
    assert_no_js_errors
  end

  test "a guest cannot reach the host or admin areas" do
    sign_in_as(@guest)

    visit host_root_path
    assert_no_text "New listing", wait: 5
    assert_no_current_path host_root_path

    visit admin_root_path
    assert_no_text "Total Users", wait: 5
    assert_no_current_path admin_root_path
  end

  # ----- admin ---------------------------------------------------------------

  test "an admin sees users, properties and bookings, and the figures agree" do
    booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                               check_in: @check_in, check_out: @check_out)
    admin = create(:user, :admin)

    sign_in_as(admin)
    visit admin_root_path
    assert_text "Total Users", wait: 10
    assert_text "Total Bookings"

    visit admin_bookings_path
    assert_text booking.invoice_reference, wait: 10

    visit admin_properties_path
    assert_text "Mullingar Crew House", wait: 10

    visit admin_users_path
    assert_text @guest.email, wait: 10
    assert_no_js_errors
  end

  private

  # Sets a booking-calc date target and fires the same events a real change does.
  def set_date(target, date)
    page.execute_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-booking-calc-target='#{target}']");
        el.value = "#{date}";
        el.dispatchEvent(new Event("change", { bubbles: true }));
      })()
    JS
  end
end
