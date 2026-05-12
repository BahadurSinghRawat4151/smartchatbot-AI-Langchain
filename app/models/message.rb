# app/models/message.rb

class Message < ApplicationRecord
  belongs_to :user, optional: true


   validates :ai_summary, presence: true

  # Optional: if you want summaries per user ordered
  scope :recent, -> { order(created_at: :desc) if column_names.include?("created_at") }
  # validates :role, :content, presence: true

  scope :for_user, ->(user_id) {
    where(user_id: user_id).order(:created_at)
  }

  # def self.history_for_user(user_id, limit: 10)
  #   for_user(user_id)
  #     .last(limit)
  #     .map { |m| { role: m.role, content: m.content } }
  # end
  #
  #  def self.history_for_user(user_id, limit: 20)
  #   where(user_id: user_id)
  #     .order(created_at: :desc)
  #     .limit(limit)
  #     .reverse
  #     .map { |m| { role: m.role, content: m.content } }
  # end
end
# class Message < ApplicationRecord
#   belongs_to :user

#   # Validations
#   validates :ai_summary, presence: true

#   # Optional: if you want summaries per user ordered
#   scope :recent, -> { order(created_at: :desc) if column_names.include?("created_at") }
# end
