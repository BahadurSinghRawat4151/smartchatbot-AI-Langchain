# class Ai::AgentToolsService
#   def initialize(session:)
#     @session = session
#   end

#   def context_for(intent:, query:, products:)
#     case intent.to_sym
#     when :cart
#       cart_tool.handle_cart_request(query: query, products: products)
#     when :checkout
#       checkout_tool.checkout
#     when :order_status
#       order_status_tool.order_status
#     when :policy
#       policy_tool.policy
#     else
#       product_context(products)
#     end.to_json
#   end

#   private

#   attr_reader :session

#   def cart_tool
#     @cart_tool ||= Ai::Tools::CartTool.new(session: session)
#   end

#   def checkout_tool
#     @checkout_tool ||= Ai::Tools::CheckoutTool.new(session: session)
#   end

#   def order_status_tool
#     @order_status_tool ||= Ai::Tools::OrderStatusTool.new
#   end

#   def policy_tool
#     @policy_tool ||= Ai::Tools::PolicyTool.new
#   end

#   def product_context(products)
#     return { tool: "ProductSearch", message: "No matching products were found." } if products.empty?

#     {
#       tool: "ProductSearch",
#       message: "#{products.size} relevant product(s) found by pgvector RAG.",
#       products: products.map { |product| product_payload(product) }
#     }
#   end

#   def product_payload(product)
#     {
#       id: product.id,
#       name: product.name,
#       brand: product.brand,
#       category: product.category,
#       price: product.price,
#       stock: product.stock
#     }
#   end
# end


# app/services/ai/agent_service.rb

class Ai::AgentToolsService
  def initialize(session:)
    @session = session
  end

  def run(query)
    llm = Langchain::LLM::OpenAI.new(
      api_key: ENV["OPENAI_API_KEY"],
      default_options: { temperature: 0.2 }
    )

    registry = Ai::ToolRegistry.new(session: @session)

    agent = Ai::Agent.new(
      llm: llm,
      tools: registry.tools
    )

    executor = Ai::AgentExecutor.new(
      agent: agent,
      tool_registry: registry
    )

    executor.run(query)
  end
end
