require "test_helper"

# The enquiry and contact forms are open to anyone on the internet. See
# SpamProtection for what stands in front of them.
class FormSpamProtectionTest < ActionDispatch::IntegrationTest
  ENQUIRY = {
    company: "Murphy Contracts Ltd", name: "John Murphy",
    email: "john@murphycontracts.ie", location: "Arklow, Co. Wicklow"
  }.freeze

  MESSAGE = {
    name: "John Murphy", email: "john@murphycontracts.ie",
    subject: "General enquiry", message: "Do you cover Cork?"
  }.freeze

  test "a genuine enquiry gets through" do
    assert_difference -> { ContactSubmission.count }, 1 do
      post enquiries_path, params: { enquiry: ENQUIRY }
    end

    assert_redirected_to root_path(anchor: "enquiry")
  end

  test "an enquiry that filled the honeypot is dropped, and told nothing" do
    assert_no_difference -> { ContactSubmission.count } do
      post enquiries_path, params: { enquiry: ENQUIRY, SpamProtection::HONEYPOT_FIELD => "http://spam.example" }
    end

    # Same redirect and same notice a person gets — nothing to learn from.
    assert_redirected_to root_path(anchor: "enquiry")
    assert_equal PagesController::ENQUIRY_THANKS, flash[:notice]
  end

  test "a contact message that filled the honeypot is dropped, and told nothing" do
    assert_no_difference -> { ContactSubmission.count } do
      post contact_path, params: { contact_submission: MESSAGE, SpamProtection::HONEYPOT_FIELD => "http://spam.example" }
    end

    assert_redirected_to contact_path
    assert_equal PagesController::CONTACT_THANKS, flash[:notice]
  end

  test "with the captcha on, an enquiry without a token is turned away" do
    stub_class_method(CaptchaVerifier, :configured?, true) do
      assert_no_difference -> { ContactSubmission.count } do
        post enquiries_path, params: { enquiry: ENQUIRY }
      end
    end

    assert_response :unprocessable_entity
    assert_match "email us directly", response.body
  end

  test "with the captcha on, a contact message without a token is turned away" do
    stub_class_method(CaptchaVerifier, :configured?, true) do
      assert_no_difference -> { ContactSubmission.count } do
        post contact_path, params: { contact_submission: MESSAGE }
      end
    end

    assert_response :unprocessable_entity
  end
end
