require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "a message needs a body" do
    assert_not build(:message, body: "").valid?
  end

  test "messages start unread and can be marked read" do
    message = create(:message)

    assert_not message.read?
    assert_includes Message.unread, message

    message.mark_as_read!

    assert message.read?
    assert_not_includes Message.unread, message
  end

  test "marking an already-read message doesn't move the timestamp" do
    message = create(:message, :read)
    original = message.read_at

    message.mark_as_read!

    assert_equal original, message.reload.read_at
  end
end
