require "test_helper"

# The onboarding path: a host applies with proof, staff review, and on approval a
# draft listing is spun up for them. This is the gate that keeps the marketplace
# vetted, so both the applicant and admin halves need to hold.
class HostApplicationsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def proof = fixture_file_upload("proof.pdf", "application/pdf")
  def biz_doc = fixture_file_upload("business.pdf", "application/pdf")

  def valid_application_params
    {
      applicant_type: "individual",
      property_address: "9 Site Road, Naas, Ireland",
      listing_url: "https://www.airbnb.com/rooms/999",
      ical_url: "https://www.airbnb.com/calendar/ical/999.ics",
      proof_documents: [ proof ]
    }
  end

  # ----- Pages render -----

  test "the application form renders for a host" do
    sign_in create(:user, :host)
    get new_host_application_path
    assert_response :success
  end

  test "admin application list and detail render" do
    application = create(:host_application, :company)
    sign_in create(:user, :admin)

    get admin_host_applications_path
    assert_response :success

    get admin_host_application_path(application)
    assert_response :success
  end

  test "the staff listing editor renders after approval" do
    application = create(:host_application)
    sign_in create(:user, :admin)
    post approve_admin_host_application_path(application)

    get edit_admin_property_path(application.reload.property)
    assert_response :success
  end

  # ----- Applying -----

  test "a host submits an application and staff are notified" do
    sign_in create(:user, :host)

    assert_difference "HostApplication.count", 1 do
      assert_enqueued_emails 1 do
        post host_applications_path, params: { host_application: valid_application_params }
      end
    end

    application = HostApplication.last
    assert application.proof_documents.attached?
    assert_redirected_to host_application_path(application)
  end

  test "an application without proof documents is rejected" do
    sign_in create(:user, :host)

    assert_no_difference "HostApplication.count" do
      post host_applications_path, params: {
        host_application: valid_application_params.merge(proof_documents: [])
      }
    end

    assert_response :unprocessable_entity
  end

  test "a company application captures entity type and documents" do
    sign_in create(:user, :host)

    post host_applications_path, params: {
      host_application: valid_application_params.merge(
        applicant_type: "company", company_name: "Musgrave Group",
        entity_type: "limited_company", business_documents: [ biz_doc ]
      )
    }

    application = HostApplication.last
    assert application.company?
    assert_equal "limited_company", application.entity_type
    assert application.business_documents.attached?
  end

  test "a guest cannot apply to host" do
    sign_in create(:user)

    post host_applications_path, params: { host_application: valid_application_params }

    assert_redirected_to root_path
  end

  test "a host only sees their own application" do
    sign_in(mine = create(:user, :host))
    theirs = create(:host_application)
    ours = create(:host_application, user: mine)

    get host_application_path(ours)
    assert_response :success

    get host_application_path(theirs)
    assert_response :not_found
  end

  # ----- Admin review -----

  test "approving builds a draft listing for the applicant and notifies them" do
    application = create(:host_application)
    sign_in create(:user, :admin)

    assert_difference "application.user.properties.count", 1 do
      assert_enqueued_email_with HostApplicationMailer, :approved, args: [ application ] do
        post approve_admin_host_application_path(application)
      end
    end

    application.reload
    assert application.approved?
    property = application.property
    assert_not_nil property
    assert property.draft?
    assert_equal application.property_address, property.address
    assert_equal application.ical_url, property.ical_url
    assert_redirected_to edit_admin_property_path(property)
  end

  test "approving a company also marks the owner's business verified" do
    application = create(:host_application, :company)
    sign_in create(:user, :admin)

    post approve_admin_host_application_path(application)

    assert application.user.reload.business_verified?
    assert_equal "Musgrave Group", application.user.company_name
  end

  test "rejecting records the reason and emails the applicant" do
    application = create(:host_application)
    sign_in create(:user, :admin)

    assert_no_difference "Property.count" do
      assert_enqueued_email_with HostApplicationMailer, :rejected, args: [ application ] do
        post reject_admin_host_application_path(application), params: { review_notes: "Couldn't verify ownership." }
      end
    end

    application.reload
    assert application.rejected?
    assert_equal "Couldn't verify ownership.", application.review_notes
  end

  test "deleting a listing built from an application doesn't error" do
    application = create(:host_application)
    sign_in create(:user, :admin)
    post approve_admin_host_application_path(application)
    property = application.reload.property

    assert_difference "Property.count", -1 do
      delete admin_property_path(property)
    end

    assert_nil application.reload.property_id
  end

  test "a non-admin cannot approve applications" do
    application = create(:host_application)
    sign_in create(:user, :host)

    post approve_admin_host_application_path(application)

    assert_redirected_to root_path
    assert application.reload.pending?
  end
end
