require "test_helper"

# IcalSyncService turns an external calendar feed into blocked nights. The
# properties that matter: it blocks exactly the feed's date range, re-syncing is
# clean (no duplication, dropped events free up), and a host's manual dates are
# never trampled by the sync.
class IcalSyncServiceTest < ActiveSupport::TestCase
  # DTEND is exclusive, so this reserves the nights of Aug 1, 2 and 3.
  ICS = <<~ICAL
    BEGIN:VCALENDAR
    BEGIN:VEVENT
    DTSTART;VALUE=DATE:20260801
    DTEND;VALUE=DATE:20260804
    SUMMARY:Reserved
    END:VEVENT
    END:VCALENDAR
  ICAL

  setup do
    @property = create(:property, ical_url: "https://example.com/cal.ics")
  end

  # Feed the parser a fixed body instead of hitting the network.
  def sync_with(body)
    service = IcalSyncService.new(@property)
    service.define_singleton_method(:fetch) { |*| body }
    service.call
  end

  test "blocks every night in the feed's range" do
    result = sync_with(ICS)

    assert result.ok?
    assert_equal 3, result.blocked_count
    blocked = @property.availabilities.where(available: false).order(:date).pluck(:date)
    assert_equal [ Date.new(2026, 8, 1), Date.new(2026, 8, 2), Date.new(2026, 8, 3) ], blocked
    assert_not @property.available_between?(Date.new(2026, 8, 1), Date.new(2026, 8, 2))
    assert_not_nil @property.reload.ical_last_synced_at
  end

  test "re-syncing the same feed doesn't duplicate rows" do
    sync_with(ICS)

    assert_no_difference "Availability.count" do
      sync_with(ICS)
    end
  end

  test "dates dropped from the feed are freed up" do
    sync_with(ICS)
    sync_with("BEGIN:VCALENDAR\nEND:VCALENDAR")

    assert_equal 0, @property.availabilities.ical.count
  end

  test "a host's manual date is never overwritten by a sync" do
    manual = create(:availability, property: @property, date: Date.new(2026, 8, 2),
                    available: true, source: :manual)

    sync_with(ICS)

    manual.reload
    assert manual.available, "manual open date should survive the sync"
    assert manual.manual?
    # Only the two nights without a manual row get iCal blocks.
    assert_equal 2, @property.availabilities.ical.count
  end

  test "a bad feed fails softly without raising" do
    service = IcalSyncService.new(@property)
    service.define_singleton_method(:fetch) { |*| raise "boom" }

    result = service.call

    assert_not result.ok?
    assert_equal "boom", result.error
  end
end
