require "test_helper"

class AccommodationEnquiryTest < ActiveSupport::TestCase
  def valid_attributes
    {
      company: "Murphy Contracts Ltd",
      name: "John Murphy",
      email: "john@murphycontracts.ie",
      phone: "087 123 4567",
      location: "Arklow, Co. Wicklow",
      dates: "Mon-Fri from 12 Oct, 6 weeks",
      crew_size: 4,
      details: "Parking for two vans."
    }
  end

  test "company, name, email and location are required" do
    enquiry = AccommodationEnquiry.new

    assert_not enquiry.valid?
    %i[company name email location].each do |field|
      assert_includes enquiry.errors.attribute_names, field
    end
  end

  test "phone, dates, crew size and details are optional" do
    assert AccommodationEnquiry.new(valid_attributes.except(:phone, :dates, :crew_size, :details)).valid?
  end

  test "the email has to look like an email" do
    assert_not AccommodationEnquiry.new(valid_attributes.merge(email: "not-an-email")).valid?
  end

  test "a crew size has to be a sensible number of people" do
    assert_not AccommodationEnquiry.new(valid_attributes.merge(crew_size: 0)).valid?
    assert_not AccommodationEnquiry.new(valid_attributes.merge(crew_size: 5_000)).valid?
  end

  test "it becomes a contact submission carrying every answer" do
    submission = AccommodationEnquiry.new(valid_attributes).to_contact_submission

    assert submission.valid?
    assert_equal "John Murphy", submission.name
    assert_equal "john@murphycontracts.ie", submission.email
    assert_equal "Accommodation enquiry — Murphy Contracts Ltd", submission.subject
    valid_attributes.except(:name, :email).each_value do |answer|
      assert_includes submission.message, answer.to_s
    end
  end

  test "blank answers are left out of the message rather than shown empty" do
    submission = AccommodationEnquiry.new(valid_attributes.except(:phone, :dates)).to_contact_submission

    assert_not_includes submission.message, "Phone:"
    assert_not_includes submission.message, "Dates:"
  end
end
