# app/services/ai/rag_service.rb

class Ai::RagService
  # Simple list of common English stop words to improve keyword extraction.
  STOP_WORDS = %w[a an and are as at be but by for if in is it of on or that the this to was with you do have i me my for of with].to_set

  def initialize
    @embedding_service = Ai::EmbeddingService.new
  end

  def search(query, embedding: nil, limit: 5)
    embedding ||= @embedding_service.embed(query)

    # 1. Vector search (semantic) for general meaning
    vector_results = Product.search_by_embedding(embedding, limit: limit)

    # 2. Keyword search (lexical) for specific terms like brand names
    keyword_results = Product.none
    keywords = query.downcase.split.reject { |word| STOP_WORDS.include?(word) || word.length < 3 }

    if keywords.present?
      # Search for products where the name or brand contains ANY of the keywords.
      # This is a simple but effective way to catch brand names, etc.
      conditions = keywords.map do |kw|
        sanitized_kw = "%#{Product.sanitize_sql_like(kw)}%"
        "products.name ILIKE '#{sanitized_kw}' OR products.brand ILIKE '#{sanitized_kw}'"
      end.join(" OR ")

      keyword_results = Product.where(conditions).limit(limit)
    end

    # 3. Combine and re-rank results
    all_results = (vector_results.to_a + keyword_results.to_a).uniq(&:id)

    # Re-rank the combined, unique results based on similarity to the original query embedding.
    all_results.sort_by { |product| -cosine_similarity(embedding, product.embedding) }
  end

  private

  def cosine_similarity(query_embedding, product_embedding)
    return -1.0 unless product_embedding.present?

    Langchain::Utils::CosineSimilarity.new(
      Array(query_embedding).map(&:to_f),
      Array(product_embedding).map(&:to_f)
    ).calculate_similarity.to_f
  end
end
