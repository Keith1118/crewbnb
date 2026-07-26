module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:stripe, :webhook_secret)

      begin
        event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      rescue JSON::ParserError
        head :bad_request and return
      rescue Stripe::SignatureVerificationError
        head :bad_request and return
      end

      case event.type
      when "payment_intent.succeeded"
        handle_payment_succeeded(event.data.object)
      when "payment_intent.payment_failed"
        handle_payment_failed(event.data.object)
      when "account.updated"
        handle_account_updated(event.data.object)
      end

      head :ok
    end

    private

    # A host's Express account changed — keep their payout-readiness in sync so
    # bookings route money correctly even if they finished onboarding elsewhere.
    def handle_account_updated(account)
      user = User.find_by(stripe_account_id: account.id)
      return unless user

      user.update!(
        stripe_charges_enabled: account.charges_enabled,
        stripe_onboarded_at: account.charges_enabled ? (user.stripe_onboarded_at || Time.current) : nil
      )
    rescue => e
      Rails.logger.error "Stripe webhook error (account.updated): #{e.message}"
    end

    def handle_payment_succeeded(payment_intent)
      payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
      return unless payment

      payment.succeeded! unless payment.succeeded?

      booking = payment.booking
      unless booking.confirmed?
        booking.confirmed!
        BookingMailer.confirmation(booking).deliver_later
      end
    rescue => e
      Rails.logger.error "Stripe webhook error (payment_intent.succeeded): #{e.message}"
    end

    def handle_payment_failed(payment_intent)
      payment = Payment.find_by(stripe_payment_intent_id: payment_intent.id)
      return unless payment

      payment.failed! unless payment.failed?
    rescue => e
      Rails.logger.error "Stripe webhook error (payment_intent.payment_failed): #{e.message}"
    end
  end
end
