# class Ai::AgentService
#   def initialize(session:)
#     @session = session
#   end

#   def run(query)
#     # Use the existing HuggingFace config instead of OpenAI
#     llm = Ai::LangchainClientService.new.chat_llm

#     registry = Ai::ToolRegistry.new(session: @session)

#     agent = Ai::Agent.new(
#       llm: llm,
#       tools: registry.tools
#     )

#     executor = Ai::AgentExecutor.new(
#       agent: agent,
#       tool_registry: registry
#     )

#     executor.run(query)
#   end
# end


# app/services/ai/agent_service.rb

class Ai::AgentService
  def initialize(session:)
    @session = session
    @logger = Rails.logger
  end

  def run(query)
    validate_query(query)

    llm = Ai::LangchainClientService.new.chat_llm
    registry = Ai::ToolRegistry.new(session: @session)
    agent = Ai::Agent.new(llm: llm, tools: registry.tools, logger: @logger)
    executor = Ai::AgentExecutor.new(
      agent: agent,
      tool_registry: registry,
      logger: @logger
    )

    result = executor.run(query)

    @logger.info("[AgentService] Completed: #{query}")
    result
  rescue => e
    @logger.error("[AgentService] Error: #{e.message}")
    @logger.error(e.backtrace.join("\n"))
    { response: "I encountered an error. Please try again." }
  end

  private

  def validate_query(query)
    raise ArgumentError, "Query cannot be blank" if query.blank?
    raise ArgumentError, "Query too long (max 500 chars)" if query.length > 500
  end
end
