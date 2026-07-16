Stripe.api_key = ENV["STRIPE_SECRET_KEY"] || Rails.application.credentials.dig(:stripe, :secret_key)

# Central place to ask "can we actually take card payments?" so booking flows
# can degrade to request-to-book when Stripe isn't configured.
module StripeConfig
  def self.configured?
    Stripe.api_key.present? &&
      (ENV["STRIPE_PUBLISHABLE_KEY"] || Rails.application.credentials.dig(:stripe, :publishable_key)).present?
  end
end
