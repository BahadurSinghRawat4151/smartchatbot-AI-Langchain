# # class Ai::Tools::ProductSearchTool < Ai::Tools::BaseTool
# #   def initialize
# #     @rag = Ai::RagService.new
# #   end

# #   def name
# #     "search_products"
# #   end

# #   def description
# #     "Search for products using semantic and keyword search"
# #   end

# #   def call(input)
# #     query = input["query"] || input[:query]

# #     return error(message: "Query is required") if query.blank?

# #     products = @rag.search(query)

# #     success(
# #       data: products.map do |p|
# #         {
# #           id: p.id,
# #           image: p.image_url,
# #           name: p.name,
# #           brand: p.brand,
# #           price: p.price,
# #           description: p.description,
# #           image: p.image_url
# #         }
# #       end,
# #       message: "#{products.size} products found"
# #     )
# #   end
# # end


# class Ai::Tools::ProductSearchTool < Ai::Tools::BaseTool
#   def initialize
#     @rag = Ai::RagService.new
#   end

#   def name
#     "search_products"
#   end

#   def description
#     "Search for products. ALWAYS use the returned product_id when performing actions like add_to_cart."
#   end

#   def call(input)
#     query = input["query"] || input[:query]
#     return error(message: "Query is required") if query.blank?

#     products = @rag.search(query)

#     results = products.map do |p|
#       {
#         product_id: p.id.to_s,   # ✅ CRITICAL FIX
#         name: p.name,
#         brand: p.brand,
#         price: p.price,
#         description: p.description,
#         image: p.images
#       }
#     end

#     Rails.logger.info("SEARCH RESULTS: #{results.inspect}")

#     success(
#       data: {
#         results: results,        # ✅ structured like LLM expects
#         total: results.size
#       },
#       message: "Found #{results.size} products. Use product_id for further actions."
#     )
#   end
# end
# app/services/ai/tools/product_search_tool.rb
# Enhanced Product Search Tool for AI Chatbot
# Provides intelligent product search with filtering, ranking, and relevance scoring

class Ai::Tools::ProductSearchTool < Ai::Tools::BaseTool
  MAX_RESULTS = 8
  DEFAULT_RESULTS = 4

  def initialize(conversation_context: nil)
    # @rag = Ai::RagService.new(cache_enabled: true)
    @rag = Ai::RagService.new
    @conversation_context = conversation_context || {}
    @logger = Rails.logger
  end

  def name
    "search_products"
  end

  def description
    "Search products. Action Input MUST be a JSON object with a single 'query' string key containing the search terms (e.g. {\"query\": \"shoes\"})."
  end

  def call(input)
    query = if input.is_a?(Hash)
              input["query"] || input["name"] || input[:query] || input[:name] || input.values.compact.reject(&:blank?).join(" ")
    else
              input.to_s
    end
    query = query.strip
    return error(message: "Query required. Please provide a 'query' key in Action Input.") if query.blank?

    limit = [ (input["limit"] || DEFAULT_RESULTS).to_i, MAX_RESULTS ].min

    begin
      products = @rag.search(query, limit: limit)

      return no_results(query) if products.empty?

      ranked = rank_products(products, query).take(limit)

      success(
        data: {
          query: query,
          results: ranked,
          total: ranked.size
        },
        message: "Products found"
      )

    rescue => e
      @logger.error("[ProductSearch] #{e.message}")
      error(message: "Search failed")
    end
  end



  private

  # 🔥 NEW RANKING (NO RATING)
  def rank_products(products, query)
    query_down = query.downcase

    products.map do |product|
      score = 0.0

      name = product.name.to_s.downcase
      brand = product.brand.to_s.downcase
      category = product.category.to_s.downcase

      # 1. Name match (strongest)
      score += 1.0 if name == query_down
      score += 0.8 if name.start_with?(query_down)
      score += 0.6 if name.include?(query_down)

      # 2. Keyword match
      words = query_down.split
      match_count = words.count { |w| name.include?(w) }
      score += (match_count.to_f / words.size) * 0.5 if words.any?

      # 3. Brand match
      score += 0.4 if brand.include?(query_down)

      # 4. Category match
      score += 0.3 if category.include?(query_down)

      # 5. Price heuristic (cheaper = slight boost)
      if product.price.present?
        normalized_price = [ product.price.to_f / 1000.0, 1.0 ].min
        score += (1 - normalized_price) * 0.2
      end

      # Add score from RAG ranking if it exists
      score += product.score if product.respond_to?(:score)

      format_product(product, score)
    end.sort_by { |p| -p[:score] }
  end

  def format_product(product, score)
    {
      product_id: product.id.to_s,
      name: product.name,
      brand: product.brand,
      category: product.category,
      price: product.price,
      description: product.description,
      stock: product.stock,
      image: product.images,
      score: score.round(2)
    }
  end

  def no_results(query)
    error(
      message: "No products found for '#{query}'",
      data: {
        suggestions: [
          "Try different keywords",
          "Search by brand (Nike, Apple, etc.)",
          "Search by category (shoes, laptops)"
        ]
      }
    )
  end
end
