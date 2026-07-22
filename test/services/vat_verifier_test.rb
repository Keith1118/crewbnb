require "test_helper"

# These tests exercise the format/normalisation logic only. The live VIES HTTP
# call is never made here — format rejection happens before any network access,
# and #acceptable? is verified from constructed Result structs — so the suite
# stays fast and offline.
class VatVerifierTest < ActiveSupport::TestCase
  test "obvious rubbish is rejected as bad format without a lookup" do
    result = VatVerifier.check("hello")

    assert result.bad_format?
    assert_not result.acceptable?
  end

  test "a well-formed number from a non-EU prefix is bad format" do
    # US isn't an EU/VIES country, so it never gets as far as a lookup.
    assert VatVerifier.check("US1234567").bad_format?
  end

  test "the number is normalised: spaces and case don't matter for format" do
    # Lower case with spaces is uppercased and stripped before the format check.
    assert_not VatVerifier.check("ie 1234567 x").bad_format?
  end

  test "a verified result is acceptable" do
    result = VatVerifier::Result.new(status: :verified, vat_number: "IE1234567X")

    assert result.acceptable?
    assert result.verified?
  end

  test "an unreachable VIES fails open — acceptable so bookings aren't blocked" do
    result = VatVerifier::Result.new(status: :unavailable, vat_number: "IE1234567X")

    assert result.acceptable?
    assert_not result.verified?
  end

  test "an invalid number is not acceptable" do
    result = VatVerifier::Result.new(status: :invalid, vat_number: "IE0000000X")

    assert_not result.acceptable?
    assert result.invalid?
  end
end
