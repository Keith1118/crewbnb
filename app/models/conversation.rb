class Conversation < ApplicationRecord
  # Associations
  belongs_to :participant_1, class_name: "User"
  belongs_to :participant_2, class_name: "User"
  belongs_to :property
  has_many :messages, dependent: :destroy

  # Scopes
  scope :for_user, ->(user) {
    where(participant_1: user).or(where(participant_2: user))
  }

  # Methods
  def other_participant(user)
    participant_1 == user ? participant_2 : participant_1
  end

  # Uses the preloaded association when there is one — the inbox renders a
  # preview per row, and querying here cost a message load (plus a user load for
  # its author) for every conversation listed.
  def last_message
    return messages.max_by(&:created_at) if messages.loaded?

    messages.order(created_at: :desc).first
  end
end
