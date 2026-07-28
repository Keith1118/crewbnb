require "application_system_test_case"

# Phone-sized viewport. Only checks things that would BREAK a flow — a control
# off-screen, covered, or unreachable — not cosmetics.
class MobileLayoutTest < ApplicationSystemTestCase
  IPHONE = [ 390, 844 ].freeze

  setup do
    page.driver.browser.manage.window.resize_to(*IPHONE)
    @host = create(:user, :host)
    @property = create(:property, user: @host, title: "Navan Crew House",
                                  price_per_night: 80, max_guests: 4)
    @guest = create(:user, :business_verified)
  end

  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "the page never scrolls sideways on a phone" do
    visit root_path
    assert_no_horizontal_overflow

    visit properties_path
    assert_no_horizontal_overflow

    visit property_path(@property)
    assert_no_horizontal_overflow
  end

  test "a guest can book from a phone" do
    sign_in_as(@guest)
    visit property_path(@property)

    fill_field "Check-in",  with: Date.current + 30
    fill_field "Check-out", with: Date.current + 32

    assert_selector "[data-booking-calc-target='total']", text: "€160", wait: 10
    submit_form_button("Request to Book", expect: /request sent|almost there|hold your dates/i)

    assert_equal 1, @guest.bookings.count
    assert_no_js_errors
  end

  test "the mobile menu opens and reaches the main sections" do
    visit root_path

    toggle = find("[data-controller~='mobile-menu'] button", match: :first)
    assert_hittable(toggle, "mobile menu toggle")
    toggle.click

    assert_text(/find stays/i, wait: 5)
    assert_no_js_errors
  end

  private

  def assert_no_horizontal_overflow
    overflow = page.evaluate_script(
      "document.documentElement.scrollWidth - document.documentElement.clientWidth"
    )
    assert overflow <= 1,
           "#{current_path} scrolls sideways by #{overflow}px at #{IPHONE.join('x')}"
  end
end
