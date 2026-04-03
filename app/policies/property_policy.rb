# frozen_string_literal: true

class PropertyPolicy < ApplicationPolicy
  # Anyone (including visitors) can browse published properties.
  def index?
    true
  end

  # Anyone can view a published property; the owner host and admins can view
  # any property regardless of status (draft, archived, etc.).
  def show?
    record.published? || owner? || admin?
  end

  # Only hosts can create properties.
  def create?
    host? || admin?
  end

  # Only the host who owns the property (or an admin) can update it.
  def update?
    owner? || admin?
  end

  # Only the host who owns the property (or an admin) can destroy it.
  def destroy?
    owner? || admin?
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    # Public listing: everyone sees published properties.
    # Hosts additionally see their own drafts/archived properties.
    # Admins see everything.
    def resolve
      if admin?
        scope.all
      elsif user&.host?
        scope.where(status: :published).or(scope.where(user: user))
      else
        scope.where(status: :published)
      end
    end
  end
end
