# app/models/message.rb

class Message < ApplicationRecord
  validates :session_id, :role, :content, presence: true

  scope :for_session, ->(sid) {
    where(session_id: sid).order(:created_at)
  }

  def self.history_for(session_id, limit: 10)
    for_session(session_id)
      .last(limit)
      .map { |m| { role: m.role, content: m.content } }
  end
end
