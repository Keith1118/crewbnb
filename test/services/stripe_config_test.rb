require "test_helper"

# StripeConfig.configured? reads Stripe.api_key (set at boot from
# STRIPE_SECRET_KEY) and the STRIPE_PUBLISHABLE_KEY env var. Both are set and
# restored directly here so the check can be exercised without real keys.
class StripeConfigTest < ActiveSupport::TestCase
  setup do
    @original_api_key = Stripe.api_key
    @original_pub_key = ENV["STRIPE_PUBLISHABLE_KEY"]
  end

  teardown do
    Stripe.api_key = @original_api_key
    if @original_pub_key.nil?
      ENV.delete("STRIPE_PUBLISHABLE_KEY")
    else
      ENV["STRIPE_PUBLISHABLE_KEY"] = @original_pub_key
    end
  end

  test "not configured when the publishable key is missing" do
    Stripe.api_key = "sk_test_123"
    ENV.delete("STRIPE_PUBLISHABLE_KEY")

    assert_not StripeConfig.configured?
  end

  test "not configured when the secret key is missing" do
    Stripe.api_key = nil
    ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_123"

    assert_not StripeConfig.configured?
  end

  test "configured when both keys are present" do
    Stripe.api_key = "sk_test_123"
    ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test_123"

    assert StripeConfig.configured?
  end
end
