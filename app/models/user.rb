class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum :role, { guest: 0, host: 1, admin: 2 }

  # Associations
  has_many :properties, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :reviews, foreign_key: :reviewer_id, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :messages, dependent: :destroy

  # Attachments
  has_one_attached :avatar
end
