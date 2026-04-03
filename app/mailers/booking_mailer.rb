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
      subject: "New booking request - #{@property.title}"
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
