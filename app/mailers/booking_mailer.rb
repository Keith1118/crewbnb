class BookingMailer < ApplicationMailer
  def confirmation(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user

    mail(
      to: @guest.email,
      subject: "Booking confirmed - #{@property.title}"
    )
  end

  def new_booking_host(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user
    @host = @property.user

    mail(
      to: @host.email,
      subject: "New booking request - #{@property.title} (awaiting your approval)"
    )
  end

  # Sent after checkout, not at booking: an invoice for a stay that hasn't
  # happened yet is a quote, and the guest's accounts team wants it once the
  # stay is a fact.
  def invoice(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user
    @host = booking.supplier

    mail(to: @guest.email, subject: "Invoice #{booking.invoice_reference} - #{@property.title}")
  end

  # The scheduled charge went through — a receipt, not a request.
  def payment_taken(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user

    mail(to: @guest.email, subject: "Payment received - #{@property.title}")
  end

  # The saved card was declined. The guest has a grace period to pay by hand
  # before the dates are released.
  def payment_failed(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user

    mail(to: @guest.email, subject: "Action needed - payment failed for #{@property.title}")
  end

  # The host approved a request-to-book stay — the guest now needs to pay to
  # lock it in.
  def payment_requested(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user

    mail(
      to: @guest.email,
      subject: "Approved — complete payment for #{@property.title}"
    )
  end

  def cancellation(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user

    mail(
      to: @guest.email,
      subject: "Booking cancelled - #{@property.title}"
    )
  end

  def status_update(booking)
    @booking = booking
    @property = booking.property
    @guest = booking.user

    mail(
      to: @guest.email,
      subject: "Booking update - #{@property.title}"
    )
  end
end
