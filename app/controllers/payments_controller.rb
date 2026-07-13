class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking
  before_action :ensure_payable, only: [ :new ]

  # Reusable PaymentIntent statuses — anything else (succeeded, processing,
  # canceled) means the intent can't take a new card attempt.
  REUSABLE_INTENT_STATUSES = %w[requires_payment_method requires_confirmation requires_action].freeze

  def new
    amount_cents = (@booking.total_price * 100).to_i
    intent = reusable_intent(amount_cents)

    if intent.nil?
      intent = Stripe::PaymentIntent.create(
        amount: amount_cents,
        currency: "eur",
        metadata: {
          booking_id: @booking.id,
          user_id: current_user.id
        }
      )

      @payment = @booking.payments.create!(
        amount: @booking.total_price,
        currency: "EUR",
        status: :pending,
        stripe_payment_intent_id: intent.id
      )
    end

    @client_secret = intent.client_secret
    @stripe_publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key) || ENV["STRIPE_PUBLISHABLE_KEY"]
  rescue Stripe::StripeError => e
    redirect_to booking_path(@booking), alert: "Unable to initialize payment: #{e.message}"
  end

  def create
    verify_and_finalize(params[:payment_intent_id])
  end

  # GET endpoint for Stripe redirect returns (3D Secure, etc.)
  def complete
    verify_and_finalize(params[:payment_intent])
  end

  private

  def set_booking
    @booking = current_user.bookings.find(params[:booking_id])
  end

  def ensure_payable
    if @booking.cancelled?
      redirect_to booking_path(@booking), alert: "This booking has been cancelled and can't be paid."
    elsif @booking.paid?
      redirect_to booking_path(@booking), notice: "This booking has already been paid."
    end
  end

  # Reuse the booking's existing pending PaymentIntent when it's still usable
  # and the amount hasn't changed, so refreshing the payment page never
  # creates duplicate intents or payment records.
  def reusable_intent(amount_cents)
    @payment = @booking.payments.pending.where.not(stripe_payment_intent_id: nil).order(created_at: :desc).first
    return nil unless @payment

    intent = Stripe::PaymentIntent.retrieve(@payment.stripe_payment_intent_id)
    return intent if REUSABLE_INTENT_STATUSES.include?(intent.status) && intent.amount == amount_cents

    nil
  rescue Stripe::StripeError
    nil
  end

  def verify_and_finalize(payment_intent_id)
    intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
    @payment = @booking.payments.find_by!(stripe_payment_intent_id: payment_intent_id)

    if intent.status == "succeeded"
      @payment.succeeded! unless @payment.succeeded?
      unless @booking.confirmed?
        @booking.confirmed!
        BookingMailer.confirmation(@booking).deliver_later
      end
      redirect_to booking_path(@booking), notice: "Payment successful. Your booking is confirmed."
    else
      @payment.failed! unless @payment.failed?
      redirect_to booking_path(@booking), alert: "Payment was not successful. Please try again."
    end
  rescue Stripe::StripeError => e
    redirect_to booking_path(@booking), alert: "Payment verification failed: #{e.message}"
  end
end
