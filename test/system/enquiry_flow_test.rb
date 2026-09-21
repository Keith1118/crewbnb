require "application_system_test_case"

# The home page is a landing page for companies while bookings are closed:
# they send their requirements and we answer by email.
class EnquiryFlowTest < ApplicationSystemTestCase
  test "a company can send an accommodation enquiry from the home page" do
    visit root_path

    fill_field "Company", with: "Murphy Contracts Ltd"
    fill_field "Your name", with: "John Murphy"
    fill_field "Email", with: "john@murphycontracts.ie"
    fill_field "Phone", with: "087 123 4567"
    fill_field "Where's the job?", with: "Arklow, Co. Wicklow"
    fill_field "Dates", with: "Mon-Fri from 12 Oct, 6 weeks"
    fill_field "How many people?", with: "4"
    fill_field "Anything else?", with: "Parking for two vans."

    assert_difference -> { ContactSubmission.count }, 1 do
      # Keyed on the flash, not "within 24 hours" — the form itself says that.
      submit_form_button("Send enquiry", expect: /we have your requirements/i)
    end

    submission = ContactSubmission.last
    assert_equal "John Murphy", submission.name
    assert_equal "john@murphycontracts.ie", submission.email
    assert_match "Murphy Contracts Ltd", submission.subject
    assert_match "Arklow, Co. Wicklow", submission.message
    assert_match "087 123 4567", submission.message
    assert_match "Parking for two vans.", submission.message
    assert_no_js_errors
  end

  test "an incomplete enquiry comes back with errors and keeps what was typed" do
    visit root_path

    # Only the company — the browser blocks a malformed email in a type="email"
    # field before it ever reaches us, so the server-side check to exercise here
    # is the missing one.
    fill_field "Company", with: "Murphy Contracts Ltd"

    assert_no_difference -> { ContactSubmission.count } do
      submit_form_button("Send enquiry", expect: /please fix the following/i)
    end

    assert_text(/email can't be blank/i)
    assert_equal "Murphy Contracts Ltd", find_field("Company").value
    # No assert_no_js_errors here: Turbo re-renders the form from a 422, which
    # Chrome always logs as a failed resource load.
  end
end
