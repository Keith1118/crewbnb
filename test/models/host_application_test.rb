require "test_helper"

# A host application is the vetted, staff-reviewed way onto the platform, so its
# validations are what stop half-finished or unverifiable submissions getting in.
class HostApplicationTest < ActiveSupport::TestCase
  test "a complete individual application is valid" do
    assert build(:host_application).valid?
  end

  test "address, listing url and ical url are required" do
    application = build(:host_application, property_address: "", listing_url: "", ical_url: "")

    assert_not application.valid?
    assert application.errors.of_kind?(:property_address, :blank)
    assert application.errors.of_kind?(:listing_url, :blank)
    assert application.errors.of_kind?(:ical_url, :blank)
  end

  test "proof documents must be attached" do
    application = build(:host_application)
    application.proof_documents.detach
    application.proof_documents = []

    assert_not application.valid?
    assert_includes application.errors[:proof_documents], "must be uploaded to show you have the place"
  end

  test "a company must name itself, pick an entity type and upload documents" do
    application = build(:host_application, applicant_type: :company,
                        company_name: "", entity_type: nil)
    application.business_documents = []

    assert_not application.valid?
    assert_includes application.errors[:company_name], "is required for a company"
    assert_includes application.errors[:entity_type], "is required for a company"
    assert_includes application.errors[:business_documents], "must be uploaded to verify the company"
  end

  test "a complete company application is valid" do
    assert build(:host_application, :company).valid?
  end
end
