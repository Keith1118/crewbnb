class ContactSubmission < ApplicationRecord
  enum :status, { pending: 0, read: 1, replied: 2 }, default: :pending

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, presence: true
  validates :message, presence: true
end
