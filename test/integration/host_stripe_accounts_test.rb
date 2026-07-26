require "test_helper"

# Host payout onboarding via Stripe Express. We create/store the connected
# account and hand the host off to Stripe's hosted onboarding.
class HostStripeAccountsTest < ActionDispatch::IntegrationTest
  test "connecting creates an express account and redirects to Stripe onboarding" do
    sign_in(host = create(:user, :host))
    account = Struct.new(:id).new("acct_new")
    link = Struct.new(:url).new("https://connect.stripe.com/setup/x")

    stub_class_method(Stripe::Account, :create, ->(*) { account }) do
      stub_class_method(Stripe::AccountLink, :create, ->(*) { link }) do
        post host_stripe_account_path
      end
    end

    assert_equal "acct_new", host.reload.stripe_account_id
    assert_redirected_to "https://connect.stripe.com/setup/x"
  end

  test "a host who already has an account reuses it" do
    sign_in(host = create(:user, :host, stripe_account_id: "acct_existing"))
    link = Struct.new(:url).new("https://connect.stripe.com/setup/y")
    created = false

    stub_class_method(Stripe::Account, :create, ->(*) { created = true; nil }) do
      stub_class_method(Stripe::AccountLink, :create, ->(*) { link }) do
        post host_stripe_account_path
      end
    end

    assert_not created, "should not create a second Stripe account"
    assert_equal "acct_existing", host.reload.stripe_account_id
  end

  test "returning from Stripe refreshes payout-readiness" do
    sign_in(host = create(:user, :host, stripe_account_id: "acct_1"))
    account = Struct.new(:charges_enabled).new(true)

    stub_class_method(Stripe::Account, :retrieve, ->(*) { account }) do
      get complete_host_stripe_account_path
    end

    assert host.reload.stripe_ready?
    assert_redirected_to host_stripe_account_path
  end

  test "a guest can't reach payout setup" do
    sign_in create(:user)
    get host_stripe_account_path
    assert_redirected_to root_path
  end
end
