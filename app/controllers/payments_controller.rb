class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking

  def new
    @payment = Payment.new(amount: @booking.total_price, currency: "EUR")
  end

  def create
    @payment = @booking.payments.build(payment_params)
    @payment.amount = @booking.total_price
    @payment.currency = "EUR"

    # Stub: mark payment as succeeded immediately
    @payment.status = :succeeded

    if @payment.save
      @booking.confirmed!
      BookingMailer.confirmation(@booking).deliver_later
      redirect_to @booking, notice: "Payment successful. Your booking is confirmed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_booking
    @booking = current_user.bookings.find(params[:booking_id])
  end

  def payment_params
    params.require(:payment).permit(:stripe_payment_intent_id)
  end
end
