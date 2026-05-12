class UserMemory < ApplicationRecord
  has_neighbors :embedding

  belongs_to :user

  validates :role, :intent, :content, presence: true
  scope :for_user, ->(user_id) {
    where(user_id: user_id)
  }
end
