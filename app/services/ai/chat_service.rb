# app/services/ai/chat_service.rb

class Ai::ChatService
  class Error < StandardError; end
SYSTEM_PROMPT = <<~PROMPT
You are "Nova" — a smart, friendly, multilingual AI shopping assistant.

## 💬 RESPONSE RULES
- You are handling a general or off-topic conversation.
- Be friendly, human, and helpful
- Keep it short and clean
- Match user language exactly
- If the user asks for specific products or shopping actions, gently guide them to ask again so the main shopping system can process it.

---

## 🌐 LANGUAGE RULE

- ALWAYS reply in user's language
- Match tone (Hinglish, Hindi, English, etc.)

---

## 🚫 BOUNDARIES

- Only shopping-related queries
- Redirect off-topic politely

---

## 🎯 PERSONALITY

- Friendly like a real store assistant
- Light enthusiasm (not robotic)
- No over-explaining
PROMPT

  def initialize
    @langchain_client = Ai::LangchainClientService.new
    @prompt_template = Langchain::Prompt::PromptTemplate.from_template(
      <<~TEMPLATE
        #{SYSTEM_PROMPT}

        Current intent:
        {intent}

        Tool Context:
        {tool_context}

        Relevant User History:
        {memory_context}

        Available Products:
        {product_context}
      TEMPLATE
    )
  end

  def respond(query:, products:,  user_id:, intent: :product, memory: [], tool_context: nil, save_conversation: true)
    product_context = format_products(products)

    # 1. Pull old, summarized memory from DB
    # db_summaries = Message.history_for_user(user_id).map do |m|
    #   m.is_a?(Hash) ? m.symbolize_keys.slice(:role, :content) : { role: m.role, content: m.content }
    # end

    # 2. Pull active, recent turns from Redis
    active_redis_history = Ai::UserMemoryService.new.get_active_conversation(user_id).map do |m|
      m.is_a?(Hash) ? m.symbolize_keys.slice(:role, :content) : { role: m.role, content: m.content }
    end

    # 3. Combine both into the unified LLM context
    history = active_redis_history

    messages = build_messages(
      query:           query,
      intent:          intent,
      tool_context:    tool_context,
      product_context: product_context,
      memory_context:  format_memory(memory),
      history:         history
    )

    response = call_llm(messages)

    save_messages(user_id, query, response) if save_conversation

    response
  end

  private

  def format_products(products)
    return "No specific products found." if products.empty?

    products.map.with_index(1) do |p, i|
      specs = p.specifications.present? ? " | Specs: #{p.specifications.to_json}" : ""
      "#{i}. #{p.image_url}| #{p.name} | Brand: #{p.brand} | Price: ₹#{p.price} | #{p.description}#{specs}"
    end.join("\n")
  end

  def format_memory(memory)
    return "No relevant semantic history found." if memory.blank?

    memory.map do |entry|
      "#{entry[:role]}: #{entry[:content]}"
    end.join("\n")
  end

  def build_messages(query:, intent:, tool_context:, product_context:, memory_context:, history:)
    system = @prompt_template.format(
      intent: intent,
      tool_context: tool_context.presence || "No tool context provided.",
      memory_context: memory_context,
      product_context: product_context
    )

    [
      { role: "system",    content: system },
      *history.map { |h| { role: h[:role], content: h[:content] } },
      { role: "user",      content: query }
    ]
  end

  def call_llm(messages)
    response = @langchain_client.chat_llm.chat(
      messages: messages,
      max_tokens: 1000,
      temperature: 0.7
    )

    text = response.chat_completion.to_s.strip
    raise Error, "Chat response did not contain any text content" if text.blank?

    text
  rescue Ai::LangchainClientService::Error => e
    raise Error, e.message
  rescue Langchain::LLM::ApiError => e
    raise Error, "Chat request failed: #{e.message}"
  end

  def save_messages(user_id, user_query, ai_response)
    # Direct DB writes for active chats are disabled to improve performance.
    # The UserMemoryService handles Redis session writes, and ConversationSummaryJob handles DB persistence.
  end
end
