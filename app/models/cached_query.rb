

# class CachedQuery < ApplicationRecord
#   has_neighbors :query_embedding

#   # cosine distance — lower = more similar
#   # 0.10 = 90% similar
#   SIMILARITY_THRESHOLD = 0.10

#   def self.find_similar(embedding)
#     nearest_neighbors(
#       :query_embedding,
#       embedding,
#       distance: "cosine"
#     )
#     .where(
#       "(query_embedding <=> ?) <= ?",
#       embedding,
#       SIMILARITY_THRESHOLD
#     )
#     .first
#   end

#   def increment_hit!
#     increment!(:hit_count)
#   end
# end


# app/models/cached_query.rb

class CachedQuery < ApplicationRecord
  has_neighbors :query_embedding

  # cosine distance — lower = more similar
  # 0.10 = 90% similar
  SIMILARITY_THRESHOLD = 0.10

  def self.find_similar(embedding)
    candidate = nearest_neighbors(
      :query_embedding,
      embedding,
      distance: "cosine"
    )
    .first

    return unless candidate
    return candidate if candidate.neighbor_distance.to_f <= SIMILARITY_THRESHOLD

    nil
  end

  def increment_hit!
    increment!(:hit_count)
  end
end
