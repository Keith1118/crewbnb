require "net/http"

# Pulls a property's external calendar feed (the iCal link Airbnb/Booking/VRBO
# give hosts) and blocks those dates on the Crewbase calendar by writing
# Availability rows with source: :ical. Re-running replaces only the :ical rows,
# so host-set (:manual) blocks/openings always win.
class IcalSyncService
  MAX_REDIRECTS = 3
  OPEN_TIMEOUT  = 10
  READ_TIMEOUT  = 15

  Result = Struct.new(:ok, :blocked_count, :error, keyword_init: true) do
    def ok? = ok
  end

  def initialize(property)
    @property = property
  end

  def call
    url = @property.ical_url.to_s.strip
    return Result.new(ok: false, error: "No iCal URL set") if url.blank?

    busy = parse_busy_dates(fetch(url))
    write(busy)
    @property.update_column(:ical_last_synced_at, Time.current)
    Result.new(ok: true, blocked_count: busy.size)
  rescue => e
    Rails.logger.warn("[IcalSync] property=#{@property.id} failed: #{e.class}: #{e.message}")
    Result.new(ok: false, error: e.message)
  end

  private

  def fetch(url, redirects = 0)
    uri = URI.parse(url)
    raise "Unsupported URL scheme" unless %w[http https].include?(uri.scheme)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    response = http.get(uri.request_uri, { "User-Agent" => "Crewbase-iCal-Sync" })

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      raise "Too many redirects" if redirects >= MAX_REDIRECTS

      fetch(response["location"], redirects + 1)
    else
      raise "HTTP #{response.code}"
    end
  end

  # Collect every occupied date across all VEVENTs. DTEND is exclusive for the
  # all-day events OTA calendars use, so we block the half-open [start, end) range.
  def parse_busy_dates(body)
    dates = Set.new
    Icalendar::Calendar.parse(body).each do |calendar|
      calendar.events.each do |event|
        start_date = to_date(event.dtstart)
        next unless start_date

        end_date = to_date(event.dtend) || (start_date + 1)
        end_date = start_date + 1 if end_date <= start_date
        (start_date...end_date).each { |date| dates << date }
      end
    end
    dates
  end

  def to_date(value)
    return nil if value.nil?

    value.respond_to?(:to_date) ? value.to_date : Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def write(busy_dates)
    @property.transaction do
      @property.availabilities.ical.delete_all

      if busy_dates.any?
        # Never clobber a host's manual row (unique index on property+date, and
        # manual intent wins) — only insert dates that aren't already set.
        existing = @property.availabilities.where(date: busy_dates.to_a).pluck(:date).to_set
        now = Time.current
        rows = busy_dates.reject { |date| existing.include?(date) }.map do |date|
          {
            property_id: @property.id,
            date: date,
            available: false,
            source: Availability.sources[:ical],
            created_at: now,
            updated_at: now
          }
        end
        Availability.insert_all(rows) if rows.any?
      end
    end
  end
end
