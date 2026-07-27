# Saves a guest's card at booking time WITHOUT charging it.
#
# Money moves later — BookingCharger takes it CHARGE_LEAD_TIME before check-in —
# so all that happens here is a Stripe SetupIntent: the guest enters their card,
# Stripe stores it against their Customer, and we keep the payment method id.
#
# The host is only told about the booking once a card is on file. A request the
# host can't ever be paid for isn't worth their attention.
class BookingCardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking
  before_action :ensure_card_needed, only: [ :new ]

  def new
    customer_id = stripe_customer_id
    intent = Stripe::SetupIntent.create(
      customer: customer_id,
      usage: "off_session",
      metadata: { booking_id: @booking.id }
    )

    @client_secret = intent.client_secret
    @stripe_publishable_key = ENV["STRIPE_PUBLISHABLE_KEY"] || Rails.application.credentials.dig(:stripe, :publishable_key)
  rescue Stripe::StripeError => e
    redirect_to booking_path(@booking), alert: "Couldn't start card setup: #{e.message}"
  end

  # Stripe sends the guest back here once the card is saved.
  def complete
    intent = Stripe::SetupIntent.retrieve(params[:setup_intent])

    if intent.status == "succeeded" && intent.payment_method.present?
      @booking.update!(stripe_payment_method_id: intent.payment_method)
      redirect_to booking_path(@booking), notice: activate_booking
    else
      redirect_to new_booking_card_path(@booking),
                  alert: "That card couldn't be saved. Please try another."
    end
  rescue Stripe::StripeError => e
    redirect_to booking_path(@booking), alert: "Couldn't confirm your card: #{e.message}"
  end

  private

  def set_booking
    @booking = current_user.bookings.find(params[:booking_id])
  end

  def ensure_card_needed
    return if @booking.stripe_payment_method_id.blank? && !@booking.cancelled?

    redirect_to booking_path(@booking)
  end

  # A card on file is what makes a booking real, so this is where the booking
  # actually starts: instant-book listings confirm (and charge at once if
  # check-in is already inside the lead time), the rest go to the host.
  def activate_booking
    if @booking.property.instant_book?
      @booking.confirmed!
      charge_now_if_due
    else
      BookingMailer.new_booking_host(@booking).deliver_later
      AutoMessenger.booking_requested(@booking)
      "Card saved and your request is with the host. You'll only be charged once they approve, #{lead_time_days} days before check-in."
    end
  end

  def charge_now_if_due
    return confirmation_notice unless @booking.charge_due?

    result = BookingCharger.call(@booking)
    if result.ok?
      "Booking confirmed and payment taken — your stay is all set."
    else
      "Booking confirmed, but we couldn't take payment. Please pay from your booking page to secure it."
    end
  end

  def confirmation_notice
    "Booking confirmed. Your card is saved and you'll be charged on #{@booking.charge_on.strftime('%-d %B')}, #{lead_time_days} days before check-in."
  end

  def lead_time_days = Booking::CHARGE_LEAD_TIME.in_days.to_i

  def stripe_customer_id
    return current_user.stripe_customer_id if current_user.stripe_customer_id.present?

    customer = Stripe::Customer.create(
      email: current_user.email,
      name: [ current_user.first_name, current_user.last_name ].compact_blank.join(" ").presence
    )
    current_user.update!(stripe_customer_id: customer.id)
    customer.id
  end
end
