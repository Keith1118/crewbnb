module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false

    def create
      event = construct_event(request.body.read, request.env["HTTP_STRIPE_SIGNATURE"])
      head :bad_request and return if event.nil?

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

    # Stripe splits our events across two endpoints that share this one URL: our
    # own account's events (payment_intent.*) and our hosts' Connect events
    # (account.updated). Each endpoint signs with its own secret, so a payload is
    # genuine if EITHER secret verifies it. Returns nil when none does.
    def construct_event(payload, sig_header)
      webhook_secrets.each do |secret|
        return Stripe::Webhook.construct_event(payload, sig_header, secret)
      rescue Stripe::SignatureVerificationError
        next
      rescue JSON::ParserError
        return nil
      end
      nil
    end

    def webhook_secrets
      [
        ENV["STRIPE_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:stripe, :webhook_secret),
        ENV["STRIPE_CONNECT_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:stripe, :connect_webhook_secret)
      ].compact_blank
    end

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
