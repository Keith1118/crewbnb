require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "for_user finds conversations on either side" do
    host  = create(:user, :host)
    guest = create(:user)
    convo = create(:conversation, participant_1: guest, participant_2: host)

    assert_includes Conversation.for_user(guest), convo
    assert_includes Conversation.for_user(host), convo
    assert_not_includes Conversation.for_user(create(:user)), convo
  end

  test "other_participant returns the person you're not" do
    guest = create(:user)
    host  = create(:user, :host)
    convo = create(:conversation, participant_1: guest, participant_2: host)

    assert_equal host, convo.other_participant(guest)
    assert_equal guest, convo.other_participant(host)
  end

  test "last_message returns the most recent one" do
    convo = create(:conversation)
    create(:message, conversation: convo, body: "first", created_at: 2.hours.ago)
    latest = create(:message, conversation: convo, body: "latest", created_at: 1.minute.ago)

    assert_equal latest, convo.last_message
  end
end
