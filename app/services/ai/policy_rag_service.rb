# app/services/ai/policy_rag_service.rb
class Ai::PolicyRagService
  def initialize
    @embedding_service = Ai::EmbeddingService.new
  end

  # 🔥 MAIN ENTRY
  def search(query, limit: 5)
    vector = @embedding_service.embed(query)

    chunks = hybrid_search(query, vector, limit)

    # group by policy (important)
    grouped = chunks.group_by(&:policy_id)

    # pick best chunk per policy
    best_chunks = grouped.map do |_policy_id, group|
      group.max_by { |c| c.score }
    end

    best_chunks.sort_by { |c| -c.score }.take(limit)
  end

  private

  # =========================
  # 🔍 HYBRID SEARCH
  # =========================

  # def hybrid_search(query, vector, limit)
  #   vector_results  = vector_search(vector, limit)
  #   keyword_results = keyword_search(query, limit)

  #   results = (vector_results + keyword_results).uniq(&:id)

  #   rank(results, query, vector)
  # end

  def hybrid_search(query, vector, limit)
    vector_results = vector_search(vector, limit)

    keyword_results =
      if query.split.size > 3
        keyword_search(query, limit)
      else
        []
      end

    results = (vector_results + keyword_results).uniq(&:id).take(limit * 2)

    rank(results, query)
  end

  # =========================
  # 🔎 VECTOR SEARCH
  # =========================

  # def vector_search(vector, limit)
  #   PolicyChunk
  #     .includes(:policy)
  #     .nearest_neighbors(:embedding, vector, distance: "cosine")
  #     .limit(limit)
  # end
  def vector_search(vector, limit)
    PolicyChunk
      .select("policy_chunks.*, (embedding <=> '[#{vector.join(',')}]') AS distance")
      .includes(:policy)
      .order("distance ASC")
      .limit(limit)
  end


  # =========================
  # 🔎 KEYWORD SEARCH
  # =========================

  def keyword_search(query, limit)
    q = "%#{PolicyChunk.sanitize_sql_like(query.downcase)}%"

    PolicyChunk
      .includes(:policy)
      .where("LOWER(content) LIKE ?", q)
      .limit(limit)
  end

  # =========================
  # 🧮 RANKING
  # =========================

  # def rank(chunks, query, vector)
  #   q = query.downcase
  #   words = q.split

  #   chunks.map do |chunk|
  #     score = 0.0
  #     content = chunk.content.downcase

  #     # 🔥 Exact phrase match
  #     score += 2.0 if content.include?(q)

  #     # 🔥 Keyword matches
  #     words.each do |w|
  #       score += 0.5 if content.include?(w)
  #     end

  #     # 🔥 Semantic similarity
  #     # if chunk.embedding.present?
  #     #   score += cosine_similarity(vector, chunk.embedding)
  #     # end
  #     #
  #     score += (1.0 - chunk.embedding_distance.to_f) if chunk.respond_to?(:embedding_distance)

  #     # 🔥 Boost by policy category
  #     if chunk.policy&.category.present?
  #       score += 0.3 if content.include?(chunk.policy.category.downcase)
  #     end

  #     chunk.define_singleton_method(:score) { score }
  #     chunk
  #   end.sort_by { |c| -c.score }
  # end
  #
  def rank(chunks, query)
    q = query.downcase
    words = q.split

    chunks.map do |chunk|
      score = 0.0
      content = chunk.content.downcase

      score += 2.0 if content.include?(q)

      words.each do |w|
        score += 0.5 if content.include?(w)
      end

      # ✅ use DB distance instead of cosine
      if chunk.respond_to?(:embedding_distance)
        score += (1.0 - chunk.embedding_distance.to_f)
      end

      chunk.define_singleton_method(:score) { score }
      chunk
    end.sort_by { |c| -c.score }
  end



  def cosine_similarity(a, b)
    Langchain::Utils::CosineSimilarity.new(
      Array(a).map(&:to_f),
      Array(b).map(&:to_f)
    ).calculate_similarity.to_f
  end
end
