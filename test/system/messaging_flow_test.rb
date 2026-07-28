require "application_system_test_case"

# Guest <-> host messaging, driven from the buttons people actually click.
class MessagingFlowTest < ApplicationSystemTestCase
  setup do
    @host = create(:user, :host, first_name: "Hannah", last_name: "Host")
    @property = create(:property, user: @host, title: "Athlone Crew House")
    @guest = create(:user, :business_verified, first_name: "Gerry", last_name: "Guest")
    @booking = create(:booking, property: @property, user: @guest,
                                check_in: Date.current + 20, check_out: Date.current + 23)
  end

  test "a guest can start a conversation from their booking and the host can reply" do
    sign_in_as(@guest)

    visit booking_path(@booking)

    # Starting a conversation must land on the conversation itself, not the
    # inbox — a GET here silently drops recipient_id/property_id and creates
    # nothing at all.
    submit_form_button("Message Host", expect: /no messages yet|Hannah Host/i)
    assert_selector "textarea", wait: 10
    conversation = Conversation.last
    assert conversation.present?, "clicking Message Host should create a conversation"
    assert_equal @property, conversation.property
    assert_equal [ @guest.id, @host.id ].sort,
                 [ conversation.participant_1_id, conversation.participant_2_id ].sort
    assert_current_path conversation_path(conversation)

    fill_field "message[body]", with: "Hi — what time can the crew check in?"
    submit_form_button("Send message", expect: /what time can the crew check in/i)

    assert_equal 1, conversation.messages.count
    assert_equal @guest, conversation.messages.last.user

    # --- host replies --------------------------------------------------------
    sign_out_via_ui
    sign_in_as(@host)

    visit host_conversations_path
    assert_text(/Gerry|Athlone Crew House/i, wait: 10)
    click_safely "a[href='#{host_conversation_path(conversation)}']",
                 expect_path: host_conversation_path(conversation)
    assert_text "what time can the crew check in", wait: 10
    # The host extranet has its own conversation view, with its own send button.
    fill_field "message[body]", with: "Any time after 3pm — keys are in the lockbox."
    submit_form_button("Send", expect: /keys are in the lockbox/i)

    conversation.reload
    assert_equal 2, conversation.messages.count
    assert_equal @host, conversation.messages.order(:created_at).last.user

    # The guest's message should be marked read now the host has opened it.
    assert conversation.messages.where(user: @guest).all?(&:read_at),
           "opening a conversation should mark the other side's messages read"
  end

  test "a host can start a conversation with their guest from the booking" do
    sign_in_as(@host)

    visit host_booking_path(@booking)
    submit_form_button("Message Guest", expect: /no messages yet|Gerry/i)

    assert_selector "textarea", wait: 10
    conversation = Conversation.last
    assert conversation.present?, "clicking Message Guest should create a conversation"
    assert_equal @property, conversation.property
    assert_current_path conversation_path(conversation)
  end
end
