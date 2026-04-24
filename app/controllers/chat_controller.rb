# app/controllers/chat_controller.rb

class ChatController < ApplicationController
  def index
    # Chat UI page
    @messages = Message.history_for(session_id)
  end

  def message
    query      = params[:query].to_s.strip
    return render json: { error: "Empty query" }, status: 400 if query.blank?

    # Step 2 — Check cache + get embedding
    cache_service = Ai::QueryCacheService.new
    cache_result  = cache_service.find_cached(query)

    if cache_result[:hit]
      # Steps 3,4 — Cache HIT → return instantly!
      render json: {
        response:  cache_result[:response],
        products:  format_products(cache_result[:products]),
        cache_hit: true
      }
    else
      # Step 5 — RAG search
      rag_service = Ai::RagService.new
      products    = rag_service.search(
        query,
        embedding: cache_result[:embedding]
      )

      # Steps 6,7 — Call AI
      chat_service = Ai::ChatService.new
      ai_response  = chat_service.respond(
        query:      query,
        products:   products,
        session_id: session_id
      )

      # Step 8 — Save to cache
      cache_service.save(
        query:     query,
        embedding: cache_result[:embedding],
        response:  ai_response,
        products:  products
      )

      # Steps 9,10 — Return response
      render json: {
        response:  ai_response,
        products:  format_products(products),
        cache_hit: false
      }
    end
  rescue Ai::EmbeddingService::Error, Ai::ChatService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("ChatController#message failed: #{e.class} - #{e.message}")
    render json: { error: "Unable to process chat message right now." }, status: :internal_server_error
  end

  private

  def session_id
    session[:chat_id] ||= SecureRandom.uuid
  end

  def format_products(products)
    products.map do |p|
      {
        id:          p.id,
        name:        p.name,
        brand:       p.brand,
        price:       p.price,
        category:    p.category,
        description: p.description
      }
    end
  end
end
