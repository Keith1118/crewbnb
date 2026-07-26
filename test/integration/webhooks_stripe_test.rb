require "test_helper"

# The Stripe webhook keeps host payout-readiness in sync — Stripe tells us when
# an Express account finishes onboarding via account.updated.
class WebhooksStripeTest < ActionDispatch::IntegrationTest
  def post_event(event)
    stub_class_method(Stripe::Webhook, :construct_event, ->(*) { event }) do
      post webhooks_stripe_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "sig" }
    end
  end

  def account_event(account_id, charges_enabled)
    account = Struct.new(:id, :charges_enabled).new(account_id, charges_enabled)
    data = Struct.new(:object).new(account)
    Struct.new(:type, :data).new("account.updated", data)
  end

  test "account.updated marks the matching host payout-ready" do
    host = create(:user, :host, stripe_account_id: "acct_1", stripe_charges_enabled: false)

    post_event account_event("acct_1", true)

    assert_response :ok
    assert host.reload.stripe_charges_enabled
    assert_not_nil host.stripe_onboarded_at
  end

  test "account.updated for an unknown account is ignored" do
    post_event account_event("acct_missing", true)

    assert_response :ok
  end
end
