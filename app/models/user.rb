class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum :role, { guest: 0, host: 1, admin: 2 }

  # Associations
  has_many :properties, dependent: :destroy
  has_many :host_applications, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :reviews, foreign_key: :reviewer_id, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :messages, dependent: :destroy

  # Attachments
  has_one_attached :avatar

  # A guest must be a verified business (valid VAT number) before booking.
  def business_verified?
    business_verified_at.present?
  end

  # A host is "onboarded" once staff have approved an application (or they
  # already have a listing). Until then they're steered to the application flow
  # and can't create listings directly — staff build the first one for them.
  def host_onboarded?
    properties.exists? || host_applications.approved.exists?
  end

  def latest_host_application
    host_applications.order(:created_at).last
  end

  # Stripe Connect (Express) payouts.
  def stripe_connected?
    stripe_account_id.present?
  end

  # True once onboarding is complete and the host can actually receive money —
  # only then do we route guest payments to them.
  def stripe_ready?
    stripe_charges_enabled?
  end
end
