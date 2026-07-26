module Host
  # Host payouts via Stripe Connect (Express). The host connects their bank
  # through Stripe's hosted onboarding; we only store the account id and whether
  # they can receive money yet.
  class StripeAccountsController < ApplicationController
    layout "host"
    before_action :authenticate_user!
    before_action :require_host

    def show
      # Pull the latest status in case they finished on another device.
      refresh_status if current_user.stripe_connected? && !current_user.stripe_ready?
    end

    # "Connect payouts" button — start (or resume) Stripe onboarding.
    def create
      start_onboarding
    end

    # Stripe sends the host back here if the onboarding link expired.
    def refresh
      start_onboarding
    end

    # Stripe's return URL once the host finishes (or bails out of) onboarding.
    def complete
      refresh_status
      notice = if current_user.stripe_ready?
        "Payouts connected — you're all set to get paid."
      else
        "Almost there — Stripe still needs a few details before you can receive payouts."
      end
      redirect_to host_stripe_account_path, notice: notice
    end

    private

    def start_onboarding
      account_id = current_user.stripe_account_id.presence || create_express_account
      link = Stripe::AccountLink.create(
        account: account_id,
        refresh_url: refresh_host_stripe_account_url,
        return_url: complete_host_stripe_account_url,
        type: "account_onboarding"
      )
      redirect_to link.url, allow_other_host: true
    rescue Stripe::StripeError => e
      redirect_to host_stripe_account_path, alert: "Couldn't start payout setup: #{e.message}"
    end

    def create_express_account
      account = Stripe::Account.create(
        type: "express",
        country: "IE",
        email: current_user.email,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true }
        }
      )
      current_user.update!(stripe_account_id: account.id)
      account.id
    end

    def refresh_status
      account = Stripe::Account.retrieve(current_user.stripe_account_id)
      current_user.update!(
        stripe_charges_enabled: account.charges_enabled,
        stripe_onboarded_at: account.charges_enabled ? (current_user.stripe_onboarded_at || Time.current) : nil
      )
    rescue Stripe::StripeError
      nil
    end

    def require_host
      unless current_user.host? || current_user.admin?
        redirect_to root_path, alert: "You must be a host to access this area."
      end
    end
  end
end
