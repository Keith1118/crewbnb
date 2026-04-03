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

  def last_message
    messages.order(created_at: :desc).first
  end
end
