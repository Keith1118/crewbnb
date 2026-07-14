Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key) || ENV["STRIPE_SECRET_KEY"]

# Central place to ask "can we actually take card payments?" so booking flows
# can degrade to request-to-book when Stripe isn't configured.
module StripeConfig
  def self.configured?
    Stripe.api_key.present? &&
      (Rails.application.credentials.dig(:stripe, :publishable_key) || ENV["STRIPE_PUBLISHABLE_KEY"]).present?
  end
end
