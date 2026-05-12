

# app/services/ai/agent.rb

class Ai::Agent
  VALID_ACTIONS = [ "final_answer" ].freeze

  def initialize(llm:, tools:, logger: nil)
    @llm = llm
    @tools = tools
    @logger = logger || Rails.logger
  end

  def decide(query:, scratchpad:)
    prompt = build_prompt(query, scratchpad)

    @logger.debug("[Agent] Prompt: #{prompt[0..200]}...")

    response = @llm.chat(
      messages: [ { role: "user", content: prompt } ]
    )

    text = extract_text(response)
    raise "No response from LLM" unless text.present?

    @logger.debug("[Agent] Response: #{text[0..200]}...")

    decision = parse_response(text)

    @logger.debug("[Agent] Decision: #{decision.inspect}")

    decision
  rescue => e
    @logger.error("[Agent] Error: #{e.message}")
    Decision.error("Failed to get decision: #{e.message}")
  end

  private

  def extract_text(response)
    # Handle different response formats
    return response.completion if response.respond_to?(:completion)

    # Langchain format
    if response.respond_to?(:raw)
      raw = response.raw
      return raw.dig("choices", 0, "message", "content")
    end

    # Direct string
    return response if response.is_a?(String)

    # Fallback
    response.to_s
  end

  def build_prompt(query, scratchpad)
    tool_list = tool_descriptions

    <<~PROMPT
    You are an AI shopping Agent.

    CRITICAL RULES:
    1. You MUST use tools to fetch data. DO NOT make up results.
    2. You MUST strictly use one of the two formats below. Do not mix them.
    3. IF A PRODUCT/COLLECTION IS NOT FOUND BY THE TOOL, YOU MUST RETURN "Product is not available" - DO NOT INVENT PRODUCTS.

    FORMAT 1 (To execute a tool - DO THIS FIRST):
    Thought: [what you need to do]
    Action: [tool_name]
    Action Input: [JSON object]

    ## PRODUCT NOT FOUND HANDLING:
    - If search_products returns empty results or {"products": []}
    - If go_to_product returns {"error": "not found"}
    - If go_to_collection returns {"error": "not found"}

    ALWAYS respond with:
    Final Answer: [Your Response]

    ## DO NOT make up products or collections when tools return no results.


    FORMAT 2 (To reply to the user - DO THIS ONLY AFTER TOOL RESULTS):
    Final Answer: [your response]

    ## NEVER return product details, lists, tables, or HTML in your Final Answer.
    If products are found by the tool:
    - ONLY return a short conversational message like: "Here are some products you might like:"
    - DO NOT include product names, prices, IDs, or image URLs. The system displays product cards automatically.

    ## Navigation Rules:
    - "take me to collection page" → Action: go_to_collection
    - "open product" or "show product page" → Action: go_to_product
    - "go to cart" → Action: go_to_cart
    - "take me to home page" → Action: go_to_home

    ## Policy Rules:
    - If user asks about return, refund, warranty, shipping, cancellation → use search_policy tool
    - Do NOT answer policy questions without using the tool

      YOU MUST call the policy tool.
      DO NOT answer directly.

    ## Dynamic Search Limits:
    If the user specifies a number (e.g., "3 products", "show me 5 products", "share me 3 products"), you MUST include "limit" in the Action Input for search_products.
    Example: Action Input: {"query": "soccer", "limit": 3}

    ## CART OPERATIONS RULE (VERY IMPORTANT)

      If user wants to remove/update items in cart:
      1. FIRST call get_cart_items
      2. Find matching product from cart
      3. THEN call remove_from_cart using product_id
      4. DO NOT use search_products for cart operations

    ###IMPORTANT:
      If search_products returns empty results, you MUST stop immediately and respond:
      Final Answer: Product is not available
      Do NOT retry search_products again.

    Available Tools:
    #{tool_list}

    Previous Steps:
    #{scratchpad}

    User Query:
    #{query}

    What is your next action? (Remember: Use FORMAT 1 to call a tool, or FORMAT 2 to answer).
    PROMPT
  end

  def tool_descriptions
    @tools.map { |t| "- #{t.name}: #{t.description}" }.join("\n")
  end

  def parse_response(text)
    # Check for final answer
    if text.include?("Final Answer:")
      final_answer = text.split("Final Answer:").last.strip
      return Decision.final_answer(final_answer)
    end

    # Parse tool call
    thought = extract_field(text, "Thought")
    action = extract_field(text, "Action")
    action_input = extract_field(text, "Action Input")

    unless action.present?
      # Fallback: If the LLM forgets "Final Answer:" but also doesn't provide a tool Action,
      # safely assume it is talking directly to the user.
      return Decision.final_answer(text.strip)
    end

    input_data = parse_input(action_input)

    Decision.new(
      action: action,
      input: input_data,
      thought: thought
    )
  rescue => e
    @logger.error("[Agent] Parse error: #{e.message}")
    Decision.error("Failed to parse response: #{e.message}")
  end

  def extract_field(text, field_name)
    # Use more precise regex that stops at newline
    pattern = /#{Regexp.escape(field_name)}:\s*(.+?)(?=\n[A-Z]|\nFinal|$)/m
    match = text.match(pattern)
    match&.captures&.first&.strip
  end

  def parse_input(input_string)
    return {} unless input_string.present?

    # Try JSON first
    begin
      return JSON.parse(input_string)
    rescue JSON::ParserError => e
      @logger.warn("[Agent] JSON parse failed: #{e.message}")
    end

    # Try to extract JSON from string
    json_match = input_string.match(/(\{.*\})/m)
    if json_match
      begin
        return JSON.parse(json_match[1])
      rescue JSON::ParserError
      end
    end

    # Return as string if can't parse
    { "query" => input_string }
  end
end

# Decision Value Object
class Decision
  attr_reader :action, :input, :thought, :errors

  def initialize(action:, input:, thought: nil, errors: [])
    @action = action
    @input = input
    @thought = thought
    @errors = errors
  end

  def valid?
    @errors.empty?
  end

  def self.final_answer(answer)
    new(action: "final_answer", input: answer)
  end

  def self.error(message)
    new(action: nil, input: nil, errors: [ message ])
  end

  def inspect
    "Decision(action=#{action}, input=#{input.inspect}, valid=#{valid?})"
  end
end
