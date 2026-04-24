# app/services/ai/chat_service.rb

class Ai::ChatService
  class Error < StandardError; end

  SYSTEM_PROMPT = <<~PROMPT
    You are a smart multilingual e-commerce assistant.

    Your responsibilities:
    1. Recommend products based on user needs
    2. Answer product related questions clearly
    3. Resolve any customer issues helpfully
    4. Always use the provided product list as your knowledge base. Do NOT make up products.
    5. List of products will be provided in the context. Refer to it for all product information.
    6.List product and their quantity is user ask for it. If user ask for 2 quantity of product then you have to check that in product list and if it is available then you can add that in your response otherwise you have to tell user that it is not available.
    7.Always refer product_loader_service.rb for product information and availability. Do NOT make up products or their availability.
    8.Don't Entertain or chat about anything other than shopping and products. Politely steer back if user tries to discuss unrelated topics.

      Important:
      1. ALWAYS use the provided product list as your knowledge base. Do NOT make up products.
      2. ALWAYS ask clarifying questions if user query is vague or could match multiple products.
      3. ALWAYS include relevant product details (name, brand, price, description) in your responses when recommending or discussing products.

    9. ALWAYS reply in the EXACT same language the user wrote in
       (Hindi → Hindi, Arabic → Arabic, English → English)

    Keep responses friendly, helpful and concise.
    Reasoning: medium
  PROMPT

  def initialize
    @langchain_client = Ai::LangchainClientService.new
    @prompt_template = Langchain::Prompt::PromptTemplate.from_template(
      <<~TEMPLATE
        #{SYSTEM_PROMPT}

        Available Products:
        {product_context}
      TEMPLATE
    )
  end

  def respond(query:, products:, session_id:)
    # Build product context for AI
    product_context = format_products(products)

    # Get conversation history (Step 10)
    history = Message.history_for(session_id)

    # Build messages array
    messages = build_messages(
      query:           query,
      product_context: product_context,
      history:         history
    )

    # Call gpt-oss-120b (Steps 6,7)
    response = call_llm(messages)

    # Step 10 — Save to conversation memory
    save_messages(session_id, query, response)

    response
  end

  private

  def format_products(products)
    return "No specific products found." if products.empty?

    products.map.with_index(1) do |p, i|
      specs = p.specifications.present? ? " | Specs: #{p.specifications.to_json}" : ""
      "#{i}. #{p.name} | Brand: #{p.brand} | Price: ₹#{p.price} | #{p.description}#{specs}"
    end.join("\n")
  end

  def build_messages(query:, product_context:, history:)
    system = @prompt_template.format(product_context: product_context)

    [
      { role: "system",    content: system },
      *history,
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

  def save_messages(session_id, user_query, ai_response)
    Message.create!(session_id: session_id, role: "user",      content: user_query)
    Message.create!(session_id: session_id, role: "assistant", content: ai_response)
  end
end
