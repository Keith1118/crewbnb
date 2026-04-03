# frozen_string_literal: true

class MessagePolicy < ApplicationPolicy
  # Only conversation participants can list messages (scoped to their
  # conversations).
  def index?
    admin? || participant?
  end

  # Only conversation participants (and admins) can view a message.
  def show?
    admin? || participant?
  end

  # Only conversation participants can create messages in that conversation.
  def create?
    admin? || participant?
  end

  # Messages are immutable; only admins can update.
  def update?
    admin?
  end

  # Only admins can destroy messages.
  def destroy?
    admin?
  end

  private

  def participant?
    return false unless user.present? && record.conversation.present?

    conversation = record.conversation
    conversation.participant_1_id == user.id || conversation.participant_2_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if admin?
        scope.all
      else
        scope.joins(:conversation).where(
          "conversations.participant_1_id = :id OR conversations.participant_2_id = :id",
          id: user.id
        )
      end
    end
  end
end
