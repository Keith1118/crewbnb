require "test_helper"

class ContactSubmissionTest < ActiveSupport::TestCase
  test "all four fields are required" do
    submission = ContactSubmission.new

    assert_not submission.valid?
    %i[name email subject message].each do |field|
      assert_includes submission.errors.attribute_names, field
    end
  end

  test "the email has to look like an email" do
    assert_not build(:contact_submission, email: "not-an-email").valid?
    assert build(:contact_submission, email: "person@company.ie").valid?
  end

  test "submissions start pending" do
    assert create(:contact_submission).pending?
  end
end
