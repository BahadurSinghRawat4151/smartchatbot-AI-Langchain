# app/services/ai/query_cache_service.rb

class Ai::QueryCacheService
  SIMILARITY_THRESHOLD = 0.90 # How similar a query must be to hit the cache
  MAX_CACHE_SIZE = 500        # Maximum number of queries kept in Redis memory
  CACHE_KEY = "ai:query_cache:entries" # Global list key in Redis

  # Scans the active Redis cache to see if an identical or highly similar query
  # was recently asked by any user. Uses vector similarity.
  def find_cached(query:, embedding:)
    entries = Ai::RedisManager.with { |redis| redis.lrange(CACHE_KEY, 0, -1) }

    best_match = nil
    highest_sim = 0.0

    # Perform an in-memory scan (safe because MAX_CACHE_SIZE is bounded to 500)
    entries.each do |entry_json|
      entry = JSON.parse(entry_json, symbolize_names: true)
      next unless entry[:embedding]

      sim = cosine_similarity(embedding, entry[:embedding])

      if sim > highest_sim && sim >= SIMILARITY_THRESHOLD
        highest_sim = sim
        best_match = entry
      end
    end

    if best_match
      # Cache hit! Return the cached AI response and hydrated product objects
      {
        hit: true,
        response: best_match[:response],
        products: Product.where(id: best_match[:product_ids] || []),
        embedding: embedding
      }
    else
      { hit: false, embedding: embedding }
    end
  rescue StandardError => e
    Rails.logger.error("QueryCacheService Error: #{e.message}")
    { hit: false, embedding: embedding }
  end

  # Pushes a new query-response pair into the global cache and trims the list
  def save(query:, embedding:, response:, products:)
    entry = {
      query: query,
      embedding: embedding,
      response: response,
      product_ids: products.map(&:id),
      timestamp: Time.now.to_i
    }.to_json

    Ai::RedisManager.with do |redis|
      # Insert at the beginning of the list and trim to ensure it doesn't grow infinitely
      redis.lpush(CACHE_KEY, entry)
      redis.ltrim(CACHE_KEY, 0, MAX_CACHE_SIZE - 1)
      redis.expire(CACHE_KEY, 24.hour.to_i) unless redis.ttl(CACHE_KEY) > 0
    end
  rescue StandardError => e
    Rails.logger.error("QueryCacheService Save Error: #{e.message}")
  end

  private

  def cosine_similarity(vec1, vec2)
    Langchain::Utils::CosineSimilarity.new(
      Array(vec1).map(&:to_f),
      Array(vec2).map(&:to_f)
    ).calculate_similarity.to_f
  end
end
