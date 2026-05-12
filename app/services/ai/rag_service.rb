# app/services/ai/rag_service.rb

# class Ai::RagService
#   # Simple list of common English stop words to improve keyword extraction.
#   STOP_WORDS = %w[a an and are as at be but by for if in is it of on or that the this to was with you do have i me my for of with].to_set

#   def initialize
#     @embedding_service = Ai::EmbeddingService.new
#   end

# def search(query, embedding: nil, limit: 5)
#   embedding ||= @embedding_service.embed(query)

#   # 1. Vector search (semantic) for general meaning
#   vector_results = Product.search_by_embedding(embedding, limit: limit)

#   # 2. Keyword search (lexical) for specific terms like brand names
#   keyword_results = Product.none


#   keywords = query
#     .downcase
#     .scan(/[[:alnum:]]+/)
#     .reject { |word| STOP_WORDS.include?(word) || word.length < 3 }

#   if keywords.present?
#     # Search for products where the name or brand contains ANY of the keywords.
#     # This is a simple but effective way to catch brand names, etc.
#     conditions = keywords.map do |kw|
#       sanitized_kw = "%#{Product.sanitize_sql_like(kw)}%"
#       "products.name ILIKE '#{sanitized_kw}' OR products.brand ILIKE '#{sanitized_kw}'"
#     end.join(" OR ")

#     keyword_results = Product.where(conditions).limit(limit)
#   end

#   # 3. Combine and re-rank results
#   all_results = (vector_results.to_a + keyword_results.to_a).uniq(&:id)

#   # Re-rank the combined, unique results based on similarity to the original query embedding.
#   all_results.sort_by { |product| -cosine_similarity(embedding, product.embedding) }
# end
#
#
#   def search(query, embedding: nil, limit: 5)
#   normalized_query = query.downcase.strip

#   # 1. Exact match
#   exact = Product.where("LOWER(name) = ?", normalized_query)
#   return exact if exact.any?

#   # 2. Phrase match
#   phrase = Product.where("name ILIKE ?", "%#{Product.sanitize_sql_like(query)}%")
#   return phrase if phrase.any?

#   # 3. Keyword AND match (strict)
#   keywords = query
#     .downcase
#     .scan(/[[:alnum:]]+/)
#     .reject { |w| STOP_WORDS.include?(w) || w.length < 3 }

#   if keywords.present?
#     conditions = keywords.map do |kw|
#       sanitized = "%#{Product.sanitize_sql_like(kw)}%"
#       "(name ILIKE '#{sanitized}' OR brand ILIKE '#{sanitized}')"
#     end.join(" AND ")

#     keyword_results = Product.where(conditions).limit(limit)
#     return keyword_results if keyword_results.any?
#   end

#   # 4. Semantic fallback
#   embedding ||= @embedding_service.embed(query)
#   vector_results = Product.search_by_embedding(embedding, limit: limit)

#   vector_results
# end

#   private

#   def cosine_similarity(query_embedding, product_embedding)
#     return -1.0 unless product_embedding.present?

#     Langchain::Utils::CosineSimilarity.new(
#       Array(query_embedding).map(&:to_f),
#       Array(product_embedding).map(&:to_f)
#     ).calculate_similarity.to_f
#   end
# end


# app/services/ai/rag_service.rb
# Enhanced RAG (Retrieval-Augmented Generation) Service
# Provides multi-strategy product search with ranking and caching

# class Ai::RagService
#   # Stop words to filter out from keyword extraction
#   STOP_WORDS = %w[
#     a an and are as at be but by for if in is it of on or that the this to was
#     with you do have i me my we he she their them than about during before after
#   ].to_set.freeze

#   # Minimum keyword length for meaningful search
#   MIN_KEYWORD_LENGTH = 3

#   # Default search limit
#   DEFAULT_LIMIT = 5

#   # Cache TTL in seconds (5 minutes)
#   CACHE_TTL = 5.minutes.freeze

#   # Search strategy weights (higher = better match)
#   RELEVANCE_WEIGHTS = {
#     exact_match: 1.0,
#     phrase_match: 0.8,
#     keyword_and: 0.6,
#     keyword_or: 0.5,
#     fuzzy_match: 0.4,
#     semantic: 0.3
#   }.freeze

#   def initialize(embedding_service: nil, cache_enabled: true)
#     @embedding_service = embedding_service || Ai::EmbeddingService.new
#     @cache_enabled = cache_enabled || Ai::QueryCacheService.new
#     @logger = Rails.logger
#   end
#   #  def initialize
#   #     @embedding_service = Ai::EmbeddingService.new
#   #   end

#   # Main search method with multi-strategy fallback
#   #
#   # @param query [String] Search query
#   # @param embedding [Array] Pre-computed embedding (optional)
#   # @param limit [Integer] Maximum results to return
#   # @param strategy [Symbol] Force specific strategy (:exact, :keyword, :semantic)
#   # @return [ActiveRecord::Relation] Ranked products
#   def search(query, embedding: nil, limit: DEFAULT_LIMIT, strategy: nil)
#     validate_inputs!(query, limit)

#     normalized_query = normalize_query(query)

#     Rails.logger.info("[RAG] Searching for: #{query} (limit: #{limit})")

#     # Try each strategy in order, return on first match
#     case strategy
#     when :exact
#       exact_search(normalized_query, limit)
#     when :keyword
#       keyword_search(normalized_query, limit)
#     when :semantic
#       semantic_search(query, embedding, limit)
#     else
#       # Multi-strategy with intelligent fallback
#       results = exact_search(normalized_query, limit)
#       return rank_results(results, query, :exact_match) if results.any?

#       results = phrase_search(normalized_query, limit)
#       return rank_results(results, query, :phrase_match) if results.any?

#       results = keyword_and_search(normalized_query, limit)
#       return rank_results(results, query, :keyword_and) if results.any?

#       results = keyword_or_search(normalized_query, limit)
#       return rank_results(results, query, :keyword_or) if results.any?

#       results = fuzzy_search(normalized_query, limit)
#       return rank_results(results, query, :fuzzy_match) if results.any?

#       # Final fallback: semantic search
#       semantic_search(query, embedding, limit)
#     end
#   rescue => e
#     @logger.error("[RAG] Search error: #{e.message}")
#     @logger.error(e.backtrace.join("\n"))
#     Product.none
#   end

#   # Exact match search (fastest, highest relevance)
#   #
#   # @param query [String] Normalized query
#   # @param limit [Integer] Result limit
#   # @return [ActiveRecord::Relation]
#   def exact_search(query, limit = DEFAULT_LIMIT)
#     cache_key = "rag:exact:#{query}"

#     return Rails.cache.read(cache_key) if @cache_enabled && Rails.cache.exist?(cache_key)

#     results = Product.where("LOWER(name) = ? OR LOWER(brand) = ?", query, query).limit(limit)

#     Rails.cache.write(cache_key, results, expires_in: CACHE_TTL) if @cache_enabled && results.any?

#     results
#   end

#   # Phrase match search (substring match, high relevance)
#   #
#   # @param query [String] Normalized query
#   # @param limit [Integer] Result limit
#   # @return [ActiveRecord::Relation]
#   def phrase_search(query, limit = DEFAULT_LIMIT)
#     cache_key = "rag:phrase:#{query}"

#     return Rails.cache.read(cache_key) if @cache_enabled && Rails.cache.exist?(cache_key)

#     search_pattern = "%#{sanitize_like(query)}%"
#     results = Product.where("name ILIKE ? OR description ILIKE ? OR brand ILIKE ?",
#                             search_pattern, search_pattern, search_pattern)
#                      .limit(limit)

#     Rails.cache.write(cache_key, results, expires_in: CACHE_TTL) if @cache_enabled && results.any?

#     results
#   end

#   # Keyword AND search (all keywords must match - strict, higher relevance)
#   #
#   # @param query [String] Normalized query
#   # @param limit [Integer] Result limit
#   # @return [ActiveRecord::Relation]
#   def keyword_and_search(query, limit = DEFAULT_LIMIT)
#     keywords = extract_keywords(query)
#     return Product.none if keywords.empty?

#     # Build SQL conditions for AND matching
#     scope = Product.all
#     keywords.each do |keyword|
#       pattern = "%#{sanitize_like(keyword)}%"
#       scope = scope.where("name ILIKE ? OR brand ILIKE ? OR description ILIKE ?",
#                           pattern, pattern, pattern)
#     end

#     scope.limit(limit)
#   end

#   # Keyword OR search (any keyword can match - broader, lower relevance)
#   #
#   # @param query [String] Normalized query
#   # @param limit [Integer] Result limit
#   # @return [ActiveRecord::Relation]
#   def keyword_or_search(query, limit = DEFAULT_LIMIT)
#     keywords = extract_keywords(query)
#     return Product.none if keywords.empty?

#     # Build OR conditions
#     conditions = keywords.map do |keyword|
#       pattern = "%#{sanitize_like(keyword)}%"
#       "(name ILIKE '#{pattern}' OR brand ILIKE '#{pattern}' OR description ILIKE '#{pattern}')"
#     end.join(" OR ")

#     Product.where(conditions).limit(limit)
#   rescue => e
#     @logger.warn("[RAG] Keyword OR search failed: #{e.message}")
#     Product.none
#   end

#   # Fuzzy match search (handles typos, misspellings - Levenshtein distance)
#   # Requires: pg with fuzzystrmatch extension
#   #
#   # @param query [String] Normalized query
#   # @param limit [Integer] Result limit
#   # @param similarity_threshold [Float] Match threshold (0.0-1.0)
#   # @return [ActiveRecord::Relation]
#   def fuzzy_search(query, limit = DEFAULT_LIMIT, similarity_threshold = 0.6)
#     return Product.none if query.length < 3

#     # Using PostgreSQL's similarity function (requires fuzzystrmatch)
#     # For MySQL, use SOUNDEX or consider a gem like fuzzy_match
#     Product.where("similarity(name, ?) > ?", query, similarity_threshold)
#            .order("similarity(name, ?) DESC", query)
#            .limit(limit)
#   rescue => e
#     @logger.warn("[RAG] Fuzzy search not available: #{e.message}")
#     Product.none
#   end

#   # Semantic search using embeddings (AI-powered, flexible matching)
#   #
#   # @param query [String] Original query
#   # @param embedding [Array] Pre-computed embedding (optional)
#   # @param limit [Integer] Result limit
#   # @param min_similarity [Float] Minimum similarity score (0.0-1.0)
#   # @return [ActiveRecord::Relation]
#   def semantic_search(query, embedding = nil, limit = DEFAULT_LIMIT, min_similarity = 0.5)
#     embedding ||= @embedding_service.embed(query)
#     return Product.none unless embedding.present?

#     # Search using vector similarity (pgvector or similar)
#     results = Product.search_by_embedding(embedding, limit: limit * 2)
#                      .select { |p| similarity_score(embedding, p.embedding) >= min_similarity }
#                      .take(limit)

#     results
#   rescue => e
#     @logger.error("[RAG] Semantic search failed: #{e.message}")
#     Product.none
#   end

#   # Batch search for multiple queries (efficient for bulk operations)
#   #
#   # @param queries [Array<String>] List of search queries
#   # @param limit [Integer] Results per query
#   # @return [Hash] { query => results }
#   def batch_search(queries, limit = DEFAULT_LIMIT)
#     queries.each_with_object({}) do |query, results|
#       results[query] = search(query, limit: limit)
#     end
#   end

#   # Advanced search with filters
#   #
#   # @param query [String] Search query
#   # @param filters [Hash] Filter options (category, price_range, rating, etc.)
#   # @param limit [Integer] Result limit
#   # @return [ActiveRecord::Relation]
#   def search_with_filters(query, filters = {}, limit = DEFAULT_LIMIT)
#     results = search(query, limit: limit * 2) # Get more results for filtering

#     # Apply category filter
#     results = results.where(category: filters[:category]) if filters[:category].present?

#     # Apply price range filter
#     if filters[:min_price].present? || filters[:max_price].present?
#       results = results.where(price: (filters[:min_price] || 0)..(filters[:max_price] || Float::INFINITY))
#     end

#     # Apply rating filter
#     results = results.where("rating >= ?", filters[:min_rating]) if filters[:min_rating].present?

#     # Apply availability filter
#     results = results.where("stock > 0") if filters[:in_stock] == true

#     results.limit(limit)
#   end

#   # Get search suggestions (autocomplete)
#   #
#   # @param query [String] Partial query
#   # @param limit [Integer] Number of suggestions
#   # @return [Array<String>]
#   def suggestions(query, limit = 5)
#     return [] if query.length < 2

#     normalized = normalize_query(query)
#     pattern = "#{sanitize_like(normalized)}%"

#     Product.where("LOWER(name) LIKE ?", pattern)
#            .distinct
#            .limit(limit)
#            .pluck(:name)
#   rescue => e
#     @logger.warn("[RAG] Suggestions error: #{e.message}")
#     []
#   end

#   private

#   # Validate input parameters
#   #
#   # @param query [String] Search query
#   # @param limit [Integer] Result limit
#   # @raises [ArgumentError] If invalid
#   def validate_inputs!(query, limit)
#     raise ArgumentError, "Query cannot be blank" if query.blank?
#     raise ArgumentError, "Limit must be positive" if limit.to_i <= 0
#   end

#   # Normalize query string
#   #
#   # @param query [String] Raw query
#   # @return [String] Normalized query
#   def normalize_query(query)
#     query.downcase.strip.gsub(/\s+/, " ")
#   end

#   # Extract meaningful keywords from query
#   #
#   # @param query [String] Normalized query
#   # @return [Array<String>] Keywords
#   def extract_keywords(query)
#     query.scan(/[[:alnum:]]+/)
#          .reject { |w| STOP_WORDS.include?(w) || w.length < MIN_KEYWORD_LENGTH }
#          .uniq
#   end

#   # Safe SQL LIKE pattern escaping
#   #
#   # @param str [String] String to escape
#   # @return [String] Escaped string
#   def sanitize_like(str)
#     str.gsub(/[\\%_]/, '\\\\\0')
#   end

#   # Calculate cosine similarity between embeddings
#   #
#   # @param query_embedding [Array] Query embedding
#   # @param product_embedding [Array] Product embedding
#   # @return [Float] Similarity score (0.0-1.0)
#   def similarity_score(query_embedding, product_embedding)
#     return 0.0 unless product_embedding.present?

#     Langchain::Utils::CosineSimilarity.new(
#       Array(query_embedding).map(&:to_f),
#       Array(product_embedding).map(&:to_f)
#     ).calculate_similarity.to_f
#   end

#   # Rank results by relevance strategy used
#   #
#   # @param results [ActiveRecord::Relation] Search results
#   # @param query [String] Original query
#   # @param strategy [Symbol] Search strategy used
#   # @return [ActiveRecord::Relation] Ranked results
#   def rank_results(results, query, strategy)
#     weight = RELEVANCE_WEIGHTS[strategy] || 0.5

#     @logger.info("[RAG] Strategy '#{strategy}' found #{results.count} results (weight: #{weight})")

#     results
#   end

#   # Clear cache for specific query or all RAG cache
#   #
#   # @param query [String] Specific query (optional)
#   def clear_cache(query = nil)
#     if query.present?
#       normalized = normalize_query(query)
#       %w[exact phrase keyword_and keyword_or fuzzy semantic].each do |strategy|
#         Rails.cache.delete("rag:#{strategy}:#{normalized}")
#       end
#     else
#       Rails.cache.delete_matched(/^rag:/)
#     end
#   end
# end


# app/services/ai/rag_service.rb

# class Ai::RagService
#   # Simple list of common English stop words to improve keyword extraction.
#   STOP_WORDS = %w[a an and are as at be but by for if in is it of on or that the this to was with you do have i me my for of with].to_set

#   def initialize
#     @embedding_service = Ai::EmbeddingService.new
#   end

#   def search(query, embedding: nil, limit: 5)
#     embedding ||= @embedding_service.embed(query)

#     # 1. Vector search (semantic) for general meaning
#     vector_results = Product.search_by_embedding(embedding, limit: limit)

#     # 2. Keyword search (lexical) for specific terms like brand names
#     keyword_results = Product.none
#     keywords = query.downcase.split.reject { |word| STOP_WORDS.include?(word) || word.length < 3 }

#     if keywords.present?
#       # Search for products where the name or brand contains ANY of the keywords.
#       # This is a simple but effective way to catch brand names, etc.
#       conditions = keywords.map do |kw|
#         sanitized_kw = "%#{Product.sanitize_sql_like(kw)}%"
#         "products.name ILIKE '#{sanitized_kw}' OR products.brand ILIKE '#{sanitized_kw}'"
#       end.join(" OR ")

#       keyword_results = Product.where(conditions).limit(limit)
#     end

#     # 3. Combine and re-rank results
#     all_results = (vector_results.to_a + keyword_results.to_a).uniq(&:id)

#     # Re-rank the combined, unique results based on similarity to the original query embedding.
#     all_results.sort_by { |product| -cosine_similarity(embedding, product.embedding) }
#   end

#   private

#   def cosine_similarity(query_embedding, product_embedding)
#     return -1.0 unless product_embedding.present?

#     Langchain::Utils::CosineSimilarity.new(
#       Array(query_embedding).map(&:to_f),
#       Array(product_embedding).map(&:to_f)
#     ).calculate_similarity.to_f
#   end
# end




class Ai::RagService
  STOP_WORDS = %w[a an and are as at be but by for if in is it of on or that the this to was with you do have i me my].to_set

  def initialize
    @embedding_service = Ai::EmbeddingService.new
  end

  # 🔥 MAIN ENTRY
  def search(query, embedding: nil, limit: 8)
    embedding ||= @embedding_service.embed(query)

    parsed = parse_query(query)

    base_scope = Product.all

    # ✅ Apply structured filters FIRST (fast + accurate)
    base_scope = apply_filters(base_scope, parsed)

    # ✅ Run searches
    vector_results  = vector_search(base_scope, embedding, limit)
    keyword_results = keyword_search(base_scope, parsed[:keywords], limit)
    tag_results     = tag_search(base_scope, parsed[:keywords], limit)
    phrase_results  = phrase_search(base_scope, query, limit)

    # ✅ Merge
    results = (
      tag_results.to_a +
      phrase_results.to_a +
      keyword_results.to_a +
      vector_results.to_a
    ).uniq(&:id)

    # ✅ Rank
    ranked = rank(results, parsed, embedding)

    ranked.take(limit)
  end

  private

 # =========================
 # 🧠 QUERY PARSER
 # =========================
 def parse_query(query)
  q = query.downcase
  words = q.scan(/\w+/)

  {
    raw: query,
    keywords: words - STOP_WORDS.to_a,
    price_max: extract_price_max(q),
    price_min: extract_price_min(q),
    category: detect_category(words),
    brand: detect_brand(words),
    tag: detect_tag(words),            # ✅ ADD THIS
    product_type: detect_type(words)   # ✅ ADD THIS
  }
end

  def extract_price_max(q)
    q[/under (\d+)/, 1]&.to_i
  end

  def extract_price_min(q)
    q[/above (\d+)/, 1]&.to_i
  end
  #   def cached_categories
  #   Rails.cache.fetch("categories", expires_in: 12.hours) do
  #     Product.distinct.pluck(:category)
  #   end
  # end

  def detect_category(words)
    Rails.cache.fetch("categories", expires_in: 12.hours) do
      Product.distinct.pluck(:category).compact.reject(&:blank?).find do |cat|
        words.any? { |w| cat.downcase.include?(w) && w.length > 2 }
      end
    end
  end

  def detect_brand(words)
    Rails.cache.fetch("brands", expires_in: 12.hours) do
      Product.distinct.pluck(:brand).compact.reject(&:blank?).find do |brand|
        words.include?(brand.downcase)
      end
    end
  end
  def detect_tag(words)
    Rails.cache.fetch("tags", expires_in: 12.hours) do
      tags = Product.pluck(:tags).flatten.compact.reject(&:blank?).map(&:downcase).uniq

      tags.find do |tag|
        words.any? { |w| (tag.include?(w) || w.include?(tag)) && w.length > 2 && tag.length > 2 }
      end
    end
  end

  def detect_type(words)
    Rails.cache.fetch("product_types", expires_in: 12.hours) do
      types = Product.distinct.pluck(:product_type).compact.reject(&:blank?).map(&:downcase)

      types.find do |type|
        words.any? { |w| type.include?(w) && w.length > 2 }
      end
    end
  end

  # =========================
  # 🔎 FILTERS
  # =========================
  def apply_filters(scope, parsed)
    scope = scope.where("price <= ?", parsed[:price_max]) if parsed[:price_max]
    scope = scope.where("price >= ?", parsed[:price_min]) if parsed[:price_min]

    scope.where("stock > 0")
  end

  # =========================
  # 🔍 SEARCH TYPES
  # =========================

  def vector_search(scope, embedding, limit)
    scope.search_by_embedding(embedding, limit: limit)
  end

  def keyword_search(scope, keywords, limit)
    return [] if keywords.blank?

    conditions = keywords.map do |kw|
      sanitized = "%#{Product.sanitize_sql_like(kw)}%"

      <<~SQL
        products.name ILIKE '#{sanitized}'
        OR products.brand ILIKE '#{sanitized}'
        OR products.category ILIKE '#{sanitized}'
        OR products.product_type ILIKE '#{sanitized}'
      SQL
    end.join(" OR ")

    scope.where(conditions).limit(limit)
  end

  def tag_search(scope, keywords, limit)
    return [] if keywords.blank?

    conditions = keywords.map do |kw|
      sanitized = "%#{Product.sanitize_sql_like(kw)}%"

      "products.tags::text ILIKE '#{sanitized}'"
    end.join(" OR ")

    scope.where(conditions).limit(limit)
  end

  def phrase_search(scope, query, limit)
    phrase = "%#{Product.sanitize_sql_like(query.downcase)}%"

    scope.where(
      "LOWER(products.name) LIKE :q OR LOWER(products.brand) LIKE :q",
      q: phrase
    ).limit(limit)
  end

  # =========================
  # 🧮 RANKING
  # =========================

  def rank(products, parsed, embedding)
    query = parsed[:raw].downcase
    words = parsed[:keywords]

    products.map do |product|
      score = 0.0

      name = product.name.to_s.downcase
      brand = product.brand.to_s.downcase
      category = product.category.to_s.downcase
      tags = Array(product.tags).map(&:downcase)

      # 🔥 Exact phrase match
      score += 2.0 if name.include?(query)

       # 🔥 Tag match (VERY STRONG)
       words.each do |w|
    score += 1.2 if tags.include?(w)
    score += 0.8 if tags.any? { |t| t.include?(w) }
  end

      # 🔥 Keyword matches
      words.each do |w|
        score += 0.6 if name.include?(w)
        score += 0.4 if brand.include?(w)
        score += 0.3 if category.include?(w)
        score += 0.7 if tags.any? { |t| t.include?(w) }
      end

      # 🔥 Semantic similarity
      if product.embedding.present?
        score += cosine_similarity(embedding, product.embedding)
      end

      # 🔥 Price boost (cheaper slightly better)
      if product.price.present?
        score += (1 - [ product.price.to_f / 5000, 1 ].min) * 0.2
      end

      # 🔥 Boost by parsed attributes
      score += 0.5 if parsed[:category] && category.include?(parsed[:category].downcase)
      score += 0.5 if parsed[:brand] && brand.include?(parsed[:brand].downcase)
      score += 0.5 if parsed[:product_type] && product.product_type.to_s.downcase.include?(parsed[:product_type].downcase)

      product.define_singleton_method(:score) { score }

      product
    end.sort_by { |p| -p.score }
  end

  def cosine_similarity(a, b)
    Langchain::Utils::CosineSimilarity.new(
      Array(a).map(&:to_f),
      Array(b).map(&:to_f)
    ).calculate_similarity.to_f
  end
  def extract_tag(q)
  tags = Product.pluck(:tags).flatten.compact.map(&:downcase).uniq

  tags.find do |tag|
    q.include?(tag)
  end
end
def extract_type(q)
  types = Product.pluck(:product_type).flatten.compact.map(&:downcase).uniq

  types.find do |type|
    q.include?(type)
  end
end
def extract_filters(query)
  q = query.downcase

  {
    tag: extract_tag(q),
    product_type: extract_type(q),
    max_price: extract_max_price(q)
  }
end
end
