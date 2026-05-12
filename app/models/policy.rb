# app/models/policy.rb
# class Policy < ApplicationRecord
#   has_neighbors :embedding, distance: "cosine"

#   validates :title, presence: true

#   def to_embedding_text
#     <<~TEXT
#       Title: #{title}
#       Category: #{category}
#       Content: #{content}
#       Tags: #{tags}
#     TEXT
#   end
# end
# app/models/policy.rb
class Policy < ApplicationRecord
  has_many :policy_chunks, dependent: :destroy

  validates :title, presence: true
end
