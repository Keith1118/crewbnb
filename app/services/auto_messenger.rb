# Sends automated, host-authored messages into the guest↔host conversation
# for a booking (booking requested, confirmed, check-in reminder, review request).
# Every send is idempotent (guarded by a per-booking timestamp) and failure-safe
# so a messaging problem can never break the booking flow.
class AutoMessenger
  def self.booking_requested(booking) = new(booking).booking_requested
  def self.booking_confirmed(booking) = new(booking).booking_confirmed
  def self.checkin_reminder(booking)  = new(booking).checkin_reminder
  def self.review_request(booking)    = new(booking).review_request

  def initialize(booking)
    @booking  = booking
    @property = booking.property
    @host     = @property.user
    @guest    = booking.user
  end

  def booking_requested
    once(:request_ack_sent_at) { request_ack_body }
  end

  def booking_confirmed
    once(:confirmation_sent_at) { confirmation_body }
  end

  def checkin_reminder
    once(:reminder_sent_at) { reminder_body }
  end

  def review_request
    once(:review_request_sent_at) { review_request_body }
  end

  private

  # Guarded send: skips if already sent, records the timestamp on success.
  def once(stamp)
    return if @host == @guest # don't message yourself
    return if @booking.public_send(stamp).present?

    deliver(yield)
    @booking.update_column(stamp, Time.current)
  rescue => e
    Rails.logger.error("AutoMessenger##{stamp} failed for booking #{@booking.id}: #{e.class} #{e.message}")
    nil
  end

  def deliver(body)
    convo = Conversation.find_or_create_by!(
      participant_1: [ @host, @guest ].min_by(&:id),
      participant_2: [ @host, @guest ].max_by(&:id),
      property: @property
    )
    message = convo.messages.create!(user: @host, body: body)
    convo.touch
    MessageMailer.new_message(message).deliver_later
    message
  end

  def guest_name
    @guest.first_name.presence || "there"
  end

  def dates
    "#{@booking.check_in.strftime('%a %d %b')} – #{@booking.check_out.strftime('%a %d %b')}"
  end

  def request_ack_body
    "Hi #{guest_name}, thanks for your booking request for #{@property.title} (#{dates}). " \
    "I'll confirm as soon as I can — usually the same day. Any questions in the meantime, just reply here."
  end

  def confirmation_body
    lines = []
    lines << "Hi #{guest_name}, your stay at #{@property.title} is confirmed. 🎉"
    lines << ""
    lines << "Check-in: from #{@property.check_in_time.presence || '3:00 PM'} on #{@booking.check_in.strftime('%A %d %B')}"
    lines << "Check-out: by #{@property.check_out_time.presence || '11:00 AM'} on #{@booking.check_out.strftime('%A %d %B')}"
    address = [ @property.address, @property.city ].compact_blank.join(", ")
    lines << "Address: #{address}" if address.present?
    lines << "Parking: free on-site parking is available." if @property.has_parking?
    lines << "Wi-Fi: #{@property.wifi_speed} throughout." if @property.wifi_speed.present?
    lines << ""
    lines << "Looking forward to having you. Reply here any time if you need anything."
    lines.join("\n")
  end

  def reminder_body
    "Hi #{guest_name}, just a reminder that your stay at #{@property.title} starts tomorrow " \
    "(#{@booking.check_in.strftime('%A %d %B')}). Check-in is from #{@property.check_in_time.presence || '3:00 PM'}. " \
    "Safe travels — see you soon!"
  end

  def review_request_body
    "Hi #{guest_name}, we hope your stay at #{@property.title} went well. " \
    "If you have a moment, a quick review would mean a lot and helps other crews book with confidence. Thanks for staying with us!"
  end
end
