class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking

  def new
    # Create a Stripe PaymentIntent
    intent = Stripe::PaymentIntent.create(
      amount: (@booking.total_price * 100).to_i,
      currency: "eur",
      metadata: {
        booking_id: @booking.id,
        user_id: current_user.id
      }
    )

    # Store client secret for the view
    @client_secret = intent.client_secret
    @stripe_publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key) || ENV["STRIPE_PUBLISHABLE_KEY"]

    # Create a pending payment record
    @payment = @booking.payments.create!(
      amount: @booking.total_price,
      currency: "EUR",
      status: :pending,
      stripe_payment_intent_id: intent.id
    )
  rescue Stripe::StripeError => e
    redirect_to booking_path(@booking), alert: "Unable to initialize payment: #{e.message}"
  end

  def create
    payment_intent_id = params[:payment_intent_id]

    # Retrieve the PaymentIntent from Stripe to verify its status
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

  # GET endpoint for Stripe redirect returns (3D Secure, etc.)
  def complete
    payment_intent_id = params[:payment_intent]

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

  private

  def set_booking
    @booking = current_user.bookings.find(params[:booking_id])
  end
end
