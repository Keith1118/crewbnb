require "test_helper"

class ContactFormTest < ActionDispatch::IntegrationTest
  test "a valid enquiry is saved and both emails are queued" do
    assert_difference "ContactSubmission.count", 1 do
      post contact_path, params: { contact_submission: {
        name: "Aoife Byrne", email: "aoife@contractor.ie",
        subject: "Crew of six", message: "Anything near Edenderry?"
      } }
    end

    assert_redirected_to contact_path
    # An auto-reply to the sender and a notification to the admin.
    assert_equal 2, enqueued_jobs.count { |j| j[:job] == ActionMailer::MailDeliveryJob }
  end

  test "an incomplete enquiry is re-rendered, not saved" do
    assert_no_difference "ContactSubmission.count" do
      post contact_path, params: { contact_submission: {
        name: "", email: "nope", subject: "", message: ""
      } }
    end

    assert_response :unprocessable_entity
  end
end
