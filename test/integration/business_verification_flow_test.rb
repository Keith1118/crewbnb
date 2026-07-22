require "test_helper"

# The VAT gate that turns a signed-up guest into someone who can book. The live
# VIES call is stubbed via VatVerifier.check so the flow can be tested offline.
class BusinessVerificationFlowTest < ActionDispatch::IntegrationTest
  setup { sign_in(@guest = create(:user)) }

  def stub_vat(result, &block)
    stub_class_method(VatVerifier, :check, result, &block)
  end

  test "a good VAT number verifies the account and records the company" do
    result = VatVerifier::Result.new(status: :verified, vat_number: "IE1234567X",
                                     name: "Verified Ltd", address: "1 Main St, Dublin")

    stub_vat(result) do
      post business_verification_path, params: { company_name: "Typed Ltd", vat_number: "IE1234567X" }
    end

    @guest.reload
    assert @guest.business_verified?
    assert_equal "Verified Ltd", @guest.company_name # official VIES name wins over the typed one
    assert_equal "IE1234567X", @guest.vat_number
  end

  test "an unreachable VIES still lets the business through (fail-open)" do
    result = VatVerifier::Result.new(status: :unavailable, vat_number: "IE1234567X")

    stub_vat(result) do
      post business_verification_path, params: { company_name: "Typed Ltd", vat_number: "IE1234567X" }
    end

    assert @guest.reload.business_verified?
  end

  test "a badly formatted number is rejected and the account stays unverified" do
    result = VatVerifier::Result.new(status: :bad_format, vat_number: "NONSENSE")

    stub_vat(result) do
      post business_verification_path, params: { company_name: "Typed Ltd", vat_number: "nonsense" }
    end

    assert_response :unprocessable_entity
    assert_not @guest.reload.business_verified?
  end

  test "an invalid number is rejected" do
    result = VatVerifier::Result.new(status: :invalid, vat_number: "IE0000000X")

    stub_vat(result) do
      post business_verification_path, params: { company_name: "Typed Ltd", vat_number: "IE0000000X" }
    end

    assert_response :unprocessable_entity
    assert_not @guest.reload.business_verified?
  end

  test "both fields are required" do
    post business_verification_path, params: { company_name: "", vat_number: "" }

    assert_response :unprocessable_entity
    assert_not @guest.reload.business_verified?
  end

  test "an already-verified guest is bounced off the form" do
    sign_in create(:user, :business_verified)

    get new_business_verification_path

    assert_response :redirect
  end
end
