require "test_helper"

# The Stripe webhook keeps host payout-readiness in sync — Stripe tells us when
# an Express account finishes onboarding via account.updated.
class WebhooksStripeTest < ActionDispatch::IntegrationTest
  def post_event(event)
    with_both_secrets do
      stub_class_method(Stripe::Webhook, :construct_event, ->(*) { event }) do
        post webhooks_stripe_path, params: "{}", headers: { "HTTP_STRIPE_SIGNATURE" => "sig" }
      end
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

  # Two Stripe endpoints share this URL — the account one (payment_intent.*) and
  # the Connect one (account.updated) — each signing with its own secret. Both
  # must be accepted, or half our events would silently 400.
  ACCOUNT_SECRET = "whsec_account_secret".freeze
  CONNECT_SECRET = "whsec_connect_secret".freeze

  def post_signed(payload, secret)
    timestamp = Time.now.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    post webhooks_stripe_path, params: payload,
      headers: { "HTTP_STRIPE_SIGNATURE" => "t=#{timestamp},v1=#{signature}", "CONTENT_TYPE" => "application/json" }
  end

  def with_both_secrets
    ENV["STRIPE_WEBHOOK_SECRET"] = ACCOUNT_SECRET
    ENV["STRIPE_CONNECT_WEBHOOK_SECRET"] = CONNECT_SECRET
    yield
  ensure
    ENV.delete("STRIPE_WEBHOOK_SECRET")
    ENV.delete("STRIPE_CONNECT_WEBHOOK_SECRET")
  end

  def unknown_account_payload
    { id: "evt_1", object: "event", type: "account.updated",
      data: { object: { id: "acct_unknown", object: "account", charges_enabled: true } } }.to_json
  end

  test "a payload signed with the account endpoint's secret is accepted" do
    with_both_secrets { post_signed(unknown_account_payload, ACCOUNT_SECRET) }

    assert_response :ok
  end

  test "a payload signed with the Connect endpoint's secret is accepted" do
    with_both_secrets { post_signed(unknown_account_payload, CONNECT_SECRET) }

    assert_response :ok
  end

  test "a payload signed with neither secret is rejected" do
    with_both_secrets { post_signed(unknown_account_payload, "whsec_wrong") }

    assert_response :bad_request
  end
end
