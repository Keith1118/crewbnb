# frozen_string_literal: true

class ReviewPolicy < ApplicationPolicy
  # Anyone can browse reviews.
  def index?
    true
  end

  # Anyone can read a review.
  def show?
    true
  end

  # Only the guest or host involved in a completed booking can create a review
  # for that booking. Admins can also create reviews.
  def create?
    return true if admin?
    return false unless user.present? && record.booking.present?
    return false unless record.booking.completed?

    booking_guest? || booking_property_host?
  end

  # Reviews are immutable; only admins can update.
  def update?
    admin?
  end

  # Only admins can destroy reviews.
  def destroy?
    admin?
  end

  private

  # The current user is the guest who made the booking.
  def booking_guest?
    record.booking.user_id == user.id
  end

  # The current user is the host who owns the property on the booking.
  def booking_property_host?
    record.booking.property.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    # Reviews are public, so everyone sees all of them.
    def resolve
      scope.all
    end
  end
end
