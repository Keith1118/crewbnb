# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  # Only admins can list users.
  def index?
    admin?
  end

  # Only admins can view user profiles (via the admin panel).
  def show?
    admin?
  end

  # Only admins can update users.
  def update?
    admin?
  end

  # Only admins can destroy users.
  def destroy?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
