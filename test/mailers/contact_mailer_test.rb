require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "the admin notification goes to the inbox we actually read" do
    submission = create(:contact_submission, email: "john@murphycontracts.ie")

    mail = ContactMailer.admin_notification(submission)

    assert_equal [ Rails.application.config.x.contact_email ], mail.to
    # Sent from the domain SPF and DKIM are signed for, but hitting reply
    # answers whoever wrote in.
    assert_equal [ "info@crewbase.ie" ], mail.from
    assert_equal [ "john@murphycontracts.ie" ], mail.reply_to
  end

  test "the auto-reply goes back to the sender" do
    submission = create(:contact_submission, email: "john@murphycontracts.ie")

    assert_equal [ "john@murphycontracts.ie" ], ContactMailer.auto_reply(submission).to
  end
end
