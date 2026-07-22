require "test_helper"

# The availability calendar: blocking nights, opening them back up, and the
# rules that stop a host from blocking dates that are already booked or in the past.
class HostCalendarTest < ActionDispatch::IntegrationTest
  setup do
    sign_in(@host = create(:user, :host))
    @property = create(:property, user: @host)
  end

  test "blocking a free future night creates a blocked availability" do
    date = Date.current + 5

    patch host_calendar_toggle_path, params: { property_id: @property.id, date: date.iso8601 }

    av = @property.availabilities.find_by(date: date)
    assert_not_nil av
    assert_equal false, av.available
  end

  test "toggling a blocked night opens it back up" do
    date = Date.current + 5
    create(:availability, property: @property, date: date, available: false)

    patch host_calendar_toggle_path, params: { property_id: @property.id, date: date.iso8601 }

    assert_nil @property.availabilities.find_by(date: date)
  end

  test "past dates cannot be blocked" do
    date = Date.current - 1

    patch host_calendar_toggle_path, params: { property_id: @property.id, date: date.iso8601 }

    assert_nil @property.availabilities.find_by(date: date)
    assert_equal "You can't change past dates.", flash[:alert]
  end

  test "a night that already has a booking cannot be blocked" do
    create(:booking, :confirmed, property: @property,
                                 check_in: Date.current + 4, check_out: Date.current + 7)
    booked_night = Date.current + 5

    patch host_calendar_toggle_path, params: { property_id: @property.id, date: booked_night.iso8601 }

    assert_nil @property.availabilities.find_by(date: booked_night)
    assert_match(/already has a booking/, flash[:alert])
  end

  test "blocking a range blocks every free night in it" do
    from = Date.current + 3
    to   = Date.current + 6

    patch host_calendar_block_range_path, params: {
      property_id: @property.id, from: from.iso8601, to: to.iso8601, range_action: "block"
    }

    (from..to).each do |date|
      assert_equal false, @property.availabilities.find_by(date: date)&.available, "expected #{date} blocked"
    end
  end

  test "a host cannot edit another host's calendar" do
    other = create(:property, user: create(:user, :host))

    patch host_calendar_toggle_path, params: { property_id: other.id, date: (Date.current + 5).iso8601 }

    assert_response :not_found
    assert_nil other.availabilities.find_by(date: Date.current + 5)
  end
end
