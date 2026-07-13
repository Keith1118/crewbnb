# frozen_string_literal: true

class BookingPolicy < ApplicationPolicy
  # Guests see their own bookings. Hosts see bookings on their properties.
  # Admins see all.
  def index?
    user.present?
  end

  # A guest can see their own booking. A host can see bookings on their
  # properties. Admins can see any booking.
  def show?
    admin? || booking_guest? || property_host?
  end

  # Only guests (and admins) can create bookings.
  def create?
    guest? || admin?
  end

  # The property host (or an admin) can update a booking (approve / reject).
  # The guest who made the booking can also update it — the controller
  # restricts guests to cancelling their own booking.
  def update?
    admin? || property_host? || booking_guest?
  end

  # Only admins can destroy bookings.
  def destroy?
    admin?
  end

  private

  # The current user is the guest who made this booking.
  def booking_guest?
    user.present? && record.user_id == user.id
  end

  # The current user is the host who owns the booked property.
  def property_host?
    user.present? && record.property.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      elsif user&.host?
        scope.joins(:property).where(properties: { user_id: user.id })
      else
        scope.where(user: user)
      end
    end
  end
end
