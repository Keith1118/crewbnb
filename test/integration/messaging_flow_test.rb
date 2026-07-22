require "test_helper"

# Guest <-> host messaging: sending, reading (unread clears on open), and the
# privacy rule that you can only see conversations you're part of.
class MessagingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @host  = create(:user, :host)
    @guest = create(:user)
    @property = create(:property, user: @host)
    @conversation = create(:conversation, participant_1: @guest, participant_2: @host, property: @property)
  end

  test "a participant can post a message" do
    sign_in @guest

    assert_difference "Message.count", 1 do
      post conversation_messages_path(@conversation), params: { message: { body: "Is it free in August?" } }
    end
  end

  test "opening a conversation marks the other side's messages read" do
    create(:message, conversation: @conversation, user: @host, body: "Yes, it's free.")
    sign_in @guest

    get conversation_path(@conversation)

    assert @conversation.messages.where(user: @host).all?(&:read?)
  end

  test "a stranger cannot read a conversation they're not in" do
    sign_in create(:user)

    get conversation_path(@conversation)

    assert_response :not_found
  end

  test "a stranger cannot post into someone else's conversation" do
    sign_in create(:user)

    assert_no_difference "Message.count" do
      post conversation_messages_path(@conversation), params: { message: { body: "Butting in" } }
    end

    assert_response :not_found
  end

  test "a blank message is rejected" do
    sign_in @guest

    assert_no_difference "Message.count" do
      post conversation_messages_path(@conversation), params: { message: { body: "" } }
    end
  end
end
