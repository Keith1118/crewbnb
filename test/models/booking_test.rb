require "test_helper"

class BookingTest < ActiveSupport::TestCase
  setup do
    @property = create(:property, price_per_night: 100, max_guests: 4)
  end

  test "nights counts the gap between check-in and check-out" do
    booking = build(:booking, check_in: Date.current + 7, check_out: Date.current + 10)

    assert_equal 3, booking.nights
  end

  test "check-out must be after check-in" do
    booking = build(:booking, check_in: Date.current + 10, check_out: Date.current + 7)

    assert_not booking.valid?
    assert_includes booking.errors.attribute_names, :check_out
  end

  test "a stay cannot start in the past" do
    booking = build(:booking, check_in: Date.current - 1, check_out: Date.current + 2)

    assert_not booking.valid?
  end

  test "a party larger than the listing cannot book it" do
    booking = build(:booking, property: @property, guests_count: 5)

    assert_not booking.valid?
  end

  # Double-booking is the failure that costs real money and real trust, so it's
  # checked from both directions: overlapping dates blocked, adjacent stays fine.
  test "overlapping dates on the same listing are rejected" do
    create(:booking, :confirmed, property: @property,
                                 check_in: Date.current + 7, check_out: Date.current + 10)

    clash = build(:booking, property: @property,
                            check_in: Date.current + 9, check_out: Date.current + 12)

    assert_not clash.valid?
  end

  test "a stay starting the day another ends is allowed" do
    create(:booking, :confirmed, property: @property,
                                 check_in: Date.current + 7, check_out: Date.current + 10)

    back_to_back = build(:booking, property: @property,
                                   check_in: Date.current + 10, check_out: Date.current + 12)

    assert back_to_back.valid?, back_to_back.errors.full_messages.to_sentence
  end

  test "a cancelled stay frees its dates up again" do
    create(:booking, :cancelled, property: @property,
                                 check_in: Date.current + 7, check_out: Date.current + 10)

    booking = build(:booking, property: @property,
                              check_in: Date.current + 7, check_out: Date.current + 10)

    assert booking.valid?, booking.errors.full_messages.to_sentence
  end

  test "each booking gets its own invoice reference" do
    first  = create(:booking, property: @property)
    second = create(:booking, property: @property,
                              check_in: Date.current + 20, check_out: Date.current + 23)

    assert first.invoice_reference.present?
    assert_not_equal first.invoice_reference, second.invoice_reference
  end

  # ----- Invoice figures -----
  # The guest always pays the listed total; VAT is backed out of it, never added.

  test "a non-VAT-registered host invoices no VAT" do
    booking = create(:booking, property: @property)

    assert_equal 0, booking.invoice_vat_rate
    assert_equal booking.invoice_gross, booking.invoice_net
  end

  test "a VAT-registered host has VAT backed out of the inclusive total" do
    host = create(:user, :host, vat_number: "IE9876543Z")
    property = create(:property, user: host, price_per_night: 100)
    booking  = create(:booking, property: property,
                                check_in: Date.current + 7, check_out: Date.current + 8)

    assert_equal Booking::DEFAULT_VAT_RATE, booking.invoice_vat_rate
    # Net must be below the inclusive total the guest was quoted.
    assert_operator booking.invoice_net, :<, booking.invoice_gross
  end
end
