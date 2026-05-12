# app/controllers/chat_controller.rb

class ChatController < ApplicationController
  def index
    # Load compressed historical summaries safely stored in Postgres
    # db_messages = Message.history_for_user(current_or_guest_user.id).map do |m|
    #   m.is_a?(Hash) ? m : { role: m.role, content: m.content }
    # end
    # Load the recent/active 10-hour session living purely in Redis memory
    # redis_messages = Ai::UserMemoryService.new.get_active_conversation(current_or_guest_user.id).map do |m|
    #   { role: m.role, content: m.content }
    # end
    #
    # redis_messages = Ai::UserMemoryService
    #   .new
    #   .get_active_conversation(actor_id)
    #   .map do |m|
    #     {
    #       role: m[:role],
    #       content: m[:content]
    #     }
    #   end

    # byebug

    # @messages = redis_messages

    # Merge them seamlessly for the frontend UI
    # @messages = redis_messages

    # byebug
  end

  def message
    query      = params[:query].to_s.strip
    return render json: { error: "Empty query" }, status: 400 if query.blank?

    embedding = Ai::EmbeddingService.new.embed(query)
    classification = Ai::IntentClassifierService.new.classify(
      query: query,
      embedding: embedding
    )


    case classification[:route]
    when :general
        respond_to_general_query(
        query: query,
        embedding: embedding,
        intent: classification[:intent]
      )
    when :product
        respond_to_product_query(
        query: query,
        embedding: embedding,
        intent: classification[:intent]
      )
    when :action
        respond_to_action_query(
        query: query,
        intent: classification[:intent]
        )

    when :policy
          respond_to_policy_query(
            query: query,
            embedding: embedding,
            intent: classification[:intent]
          )
    else
      respond_to_general_query(
        query: query,
        embedding: embedding,
        intent: classification[:intent]
      )
    end
    # if classification[:intent] == :policy
    #   respond_to_policy_query(
    #     query: query,
    #     embedding: embedding,
    #     intent: classification[:intent]
    #   )

    # end


  rescue Ai::EmbeddingService::Error, Ai::ChatService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("ChatController#message failed: #{e.class} - #{e.message}")
    render json: { error: "Unable to process chat message right now." }, status: :internal_server_error
  end

  private

    def respond_to_policy_query(query:, embedding:, intent:)
      return unless intent == :policy
      memory_service = Ai::UserMemoryService.new

      # 🔥 semantic search on chunks
      chunks = Ai::PolicyRagService.new.search(query)

      # build context
      context = chunks.map do |c|
        "Policy: #{c.policy.title}\n#{c.content}"
      end.join("\n\n")

      # generate answer
      ai_response = Ai::ChatService.new.respond(
        query: query,
        products: [],
        user_id: actor_id,
        intent: intent,
        tool_context: "Answer strictly from policy context:\n\n#{context}", # 👈 IMPORTANT
        save_conversation: false
      )

      memory_service.save_turn(
        user_id: actor_id,
        intent: intent,
        query: query,
        query_embedding: embedding,
        response: ai_response
      )

      render json: {
        response: ai_response,
        products: [],
        policies: chunks.map do |c|
          {
            title: c.policy.title,
            content: c.content
          }
        end,
        intent: intent
      }
    end

  def respond_to_action_query(query:, intent:)
    return unless [ :navigation, :cart, :checkout, :home, :main ].include?(intent)
    agent_result = Ai::AgentService.new(session: session).run(query)

    render json: {
      response: agent_result[:response],
      products: [],
      navigation: agent_result[:navigation],
      cart_url: cart_path,
      checkout_url: checkout_path,
      intent: intent
    }
  end

  def respond_to_general_query(query:, embedding:, intent:)
    return if intent != :general
    cache_service = Ai::QueryCacheService.new
    cache_result  = cache_service.find_cached(query: query, embedding: embedding)

    if cache_result[:hit]
      memory_service = Ai::UserMemoryService.new
      memory_service.save_turn(
        user_id: actor_id,
        intent: intent,
        query: query,
        query_embedding: embedding,
        response: cache_result[:response]
      )


      return render json: {
        response: cache_result[:response],
        products: [],
        cache_hit: true,
        intent: intent
      }


    end


    chat_service = Ai::ChatService.new
    ai_response  = chat_service.respond(
      query: query,
      products: [],
      # session_id: session_id,
      user_id: actor_id,
      intent: intent,
      tool_context: "General/off-topic route: answer briefly, then redirect to shopping help when appropriate.",
      save_conversation: false
    )

    cache_service.save(
      query: query,
      embedding: embedding,
      response: ai_response,
      products: []
    )
    memory_service = Ai::UserMemoryService.new
    memory_service.save_turn(
      user_id: actor_id,
      intent: intent,
      query: query,
      query_embedding: embedding,
      response: ai_response
    )



    render json: {
      response: ai_response,
      products: [],
      cache_hit: false,
      intent: intent
    }
  end


  def respond_to_product_query(query:, embedding:, intent:)
     return unless intent == :product
    memory_service = Ai::UserMemoryService.new

    memory = memory_service.relevant_history(
      user_id: actor_id,
      embedding: embedding
    )


    # ✅ NEW: Use agent instead of manual tool + rag orchestration
    agent_result = Ai::AgentService.new(session: session).run(query)

    # ✅ Use products from Agent's tool instead of a second naive RAG search
    if agent_result[:products].present?
      formatted_products = agent_result[:products].map do |p|
        {
          id: p[:product_id] || p["product_id"],
          image: p[:image] || p["image"],
          name: p[:name] || p["name"],
          brand: p[:brand] || p["brand"],
          price: p[:price] || p["price"],
          category: p[:category] || p["category"],
          description: p[:description] || p["description"]
        }
      end
    else
      products = Ai::RagService.new.search(query, embedding: embedding)
      formatted_products = format_products(products)
    end

    # The agent's final textual response
    ai_response = agent_result[:response] || "Sorry, I could not process that."

    memory_service.save_turn(
      user_id: actor_id,
      intent: intent,
      query: query,
      query_embedding: embedding,
      response: ai_response # Save the text part to memory
    )

    render json: {
      response: clean_ai_response(ai_response),
      products: formatted_products,
      navigation: agent_result[:navigation], # Pass navigation data to the frontend
      cart_url: cart_path,
      checkout_url: checkout_path,
      cache_hit: false,
      intent: intent
    }
  end


  def format_products(products)
    products.map do |p|
      {
        id:          p.id,
        image:       p.images,
        name:        p.name,
        brand:       p.brand,
        price:       p.price,
        category:    p.category,
        description: p.description
      }
    end
  end
  def clean_ai_response(text)
  return "" if text.include?("| Product ID |") # detect table
  text
end
end
