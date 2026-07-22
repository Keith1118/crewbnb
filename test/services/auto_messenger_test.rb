require "test_helper"

# AutoMessenger posts host-authored messages into the guest<->host thread at key
# moments. The two properties that matter: it never sends the same one twice
# (guarded by a per-booking timestamp), and a messaging failure never bubbles up
# to break the booking flow.
class AutoMessengerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @host    = create(:user, :host)
    @property = create(:property, user: @host)
    @guest   = create(:user)
    @booking = create(:booking, property: @property, user: @guest, status: :confirmed)
  end

  test "booking_confirmed posts one message and stamps the booking" do
    assert_difference "Message.count", 1 do
      AutoMessenger.booking_confirmed(@booking)
    end

    assert_not_nil @booking.reload.confirmation_sent_at
  end

  test "sending the same message twice is a no-op" do
    AutoMessenger.booking_confirmed(@booking)

    assert_no_difference "Message.count" do
      AutoMessenger.booking_confirmed(@booking)
    end
  end

  test "the message is authored by the host, into a shared conversation" do
    AutoMessenger.booking_confirmed(@booking)
    message = Message.last

    assert_equal @host, message.user
    convo = message.conversation
    assert_equal [ @guest, @host ].sort_by(&:id), [ convo.participant_1, convo.participant_2 ].sort_by(&:id)
  end

  test "a host booking their own place doesn't get messaged" do
    own = create(:property, user: @host)
    booking = create(:booking, property: own, user: @host, status: :confirmed)

    assert_no_difference "Message.count" do
      AutoMessenger.booking_confirmed(booking)
    end
  end

  test "a delivery failure is swallowed, not raised, and leaves no stamp" do
    # Force the underlying send to blow up; the booking flow must survive it.
    stub_class_method(Conversation, :find_or_create_by!, ->(*) { raise "boom" }) do
      assert_nothing_raised do
        AutoMessenger.booking_confirmed(@booking)
      end
    end

    assert_nil @booking.reload.confirmation_sent_at, "a failed send must not record a sent timestamp"
  end
end
