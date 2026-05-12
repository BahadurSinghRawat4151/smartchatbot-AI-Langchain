# app/models/policy_chunk.rb
class PolicyChunk < ApplicationRecord
  belongs_to :policy

  has_neighbors :embedding
end
