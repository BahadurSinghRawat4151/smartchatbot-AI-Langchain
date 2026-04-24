# app/services/ai/query_cache_service.rb

class Ai::QueryCacheService
  SIMILARITY_THRESHOLD = 0.90

  def initialize
    @embedding_service = Ai::EmbeddingService.new
  end

  # Step 3 — Check cache
  def find_cached(query)
    embedding = @embedding_service.embed(query)
    cached    = nearest_cache_match_for(embedding)

    if cached
      # Step 4 — Cache HIT!
      cached.increment_hit!
      {
        hit:      true,
        response: cached.ai_response,
        products: Product.where(id: cached.product_ids),
        embedding: embedding
      }
    else
      # Step 5 — Cache MISS
      {
        hit:      false,
        embedding: embedding
      }
    end
  end

  # Step 8 — Save to cache
  def save(query:, embedding:, response:, products:)
    CachedQuery.create!(
      query_text:      query,
      query_embedding: embedding,
      ai_response:     response,
      product_ids:     products.map(&:id)
    )
  end

  private

  def nearest_cache_match_for(embedding)
    candidate = CachedQuery.nearest_neighbors(
      :query_embedding,
      embedding,
      distance: "cosine"
    ).first

    return unless candidate

    similarity = Langchain::Utils::CosineSimilarity.new(
      Array(embedding).map(&:to_f),
      Array(candidate.query_embedding).map(&:to_f)
    ).calculate_similarity.to_f

    similarity >= SIMILARITY_THRESHOLD ? candidate : nil
  end
end
