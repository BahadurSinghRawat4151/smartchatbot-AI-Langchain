# # app/services/ai/agent_executor.rb
# class Ai::AgentExecutor
#   MAX_STEPS = 5

#   def initialize(agent:, tool_registry:)
#     @agent = agent
#     @tool_registry = tool_registry
#   end

#   def run(query)
#     scratchpad = ""
#     steps = 0

#     while steps < MAX_STEPS

#       # decision = @agent.decide(query: query, scratchpad: scratchpad)

#       # action = decision["action"]
#       # input  = decision["input"]

#       # if action == "final_answer"
#       #   return input
#       # end

#       # tool = @tool_registry.find(action)

#       # unless tool
#       #   return "Unknown tool: #{action}"
#       # end

#       # result = tool.call(input)

#       # scratchpad += <<~STEP

#       # Tool used: #{action}
#       # Input: #{input}
#       # Result: #{result.to_json}
#       # STEP
#       #
#       # scratchpad += <<~STEP

#       #   Thought: #{decision["thought"] || "Used tool"}
#       #   Action: #{action}
#       #   Action Input: #{input}
#       #   Observation: #{result.to_json}

#       #   STEP

#       # steps += 1
#       #
#       decision = @agent.decide(query: query, scratchpad: scratchpad)

#       action = decision["action"]
#       input  = decision["input"]

#       if action == "final_answer"
#         return decision["input"]
#       end

#       tool = @tool_registry.find(action)

#       return "Unknown tool: #{action}" unless tool

#       result = tool.call(input)

#       scratchpad += <<~STEP
#       Thought: #{decision["thought"]}
#       Action: #{action}
#       Action Input: #{input}
#       Observation: #{result.to_json}
#       STEP
#     end

#     "Max steps reached. Unable to complete request."
#   end

#   def parse_decision(text)
#   action = text.match(/Action:\s*(\w+)/)&.captures&.first
#   input  = text.match(/Action Input:\s*(\{.*\})/m)&.captures&.first

#   {
#     "action" => action,
#     "input"  => input ? JSON.parse(input) : {}
#   }
# end
# end
# app/services/ai/agent_executor.rb

class Ai::AgentExecutor
  MAX_STEPS = 5
  STEP_TIMEOUT = 30.seconds
  NAVIGATION_TOOLS = %w[go_to_collection go_to_product go_to_cart go_to_home].freeze

  def initialize(agent:, tool_registry:, logger: nil)
    @agent = agent
    @tool_registry = tool_registry
    @logger = logger || Rails.logger
  end

  def run(query)
    scratchpad = ""
    steps = 0
    extracted_products = nil

    loop do
      # Safety checks. Return a hash for the controller.
      return { response: "Max steps reached" } if steps >= MAX_STEPS

      begin
        @logger.info("[AgentExecutor] Step #{steps + 1}/#{MAX_STEPS}")

        # Get decision from agent
        decision = @agent.decide(query: query, scratchpad: scratchpad)


        raw = decision.respond_to?(:raw_output) ? decision.raw_output.to_s.strip : ""
          # 🚨 Reject mixed outputs
          if raw.include?("Final Answer:") && raw.include?("Action:")
            @logger.warn("[AgentExecutor] Invalid mixed output detected")

            scratchpad += "\nSYSTEM: Your previous response was invalid. You mixed Final Answer and Action. Follow format strictly.\n"
            steps += 1
            next
          end
        return { response: invalid_decision_error(decision) } unless decision.valid?

        action = decision.action
        input = decision.input

        # Check for final answer
        # if action == "final_answer"
        #   @logger.info("[AgentExecutor] Final answer: #{input[0..100]}")
        #   return { response: input, products: extracted_products }
        # end
        #
        if action == "final_answer"
          if input.match?(/Action:\s*\w+/)
            @logger.warn("[AgentExecutor] Invalid Final Answer format")

            scratchpad = add_correction(
              scratchpad,
              "You returned tool instructions inside Final Answer. This is INVALID. Use Action format."
            )

            steps += 1
            next
          end

          return { response: input, products: extracted_products }
        end


        if steps == 0 && action == "final_answer"
          @logger.warn("[AgentExecutor] Premature final answer")

          scratchpad += "\nSYSTEM: You must use tools before answering.\n"
          steps += 1
          next
        end
        if action == "final_answer" && input.include?("Action:")
          scratchpad = add_correction(
            scratchpad,
            "INVALID FORMAT: Do NOT include Thought/Action inside Final Answer. Use FORMAT 1 for tool calls."
          )
          next
        end

        if action.blank?
          @logger.warn("[AgentExecutor] Missing action")

          scratchpad += "\nSYSTEM: You must provide an Action.\n"
          steps += 1
          next
        end

        # Find and execute tool
        tool = @tool_registry.find(action)
        return { response: "Unknown tool: #{action}" } unless tool

        @logger.info("[AgentExecutor] Executing tool: #{action}")

        result = execute_tool_safely(tool, input)

        # If search tool succeeds, capture products so we don't lose them
        if tool.name == "search_products" && result.is_a?(Hash) && result[:status] == "success"
          extracted_products = result.dig(:data, :results) || result.dig("data", "results")
        end


        # If a navigation tool succeeds, terminate and return its data
        if NAVIGATION_TOOLS.include?(tool.name) && result.is_a?(Hash) && result[:status] == "success"
          @logger.info("[AgentExecutor] Navigation action successful. Terminating.")
          return { response: result[:message], navigation: result[:data], products: extracted_products }
        end

        # Build scratchpad with this step
        scratchpad = update_scratchpad(
          scratchpad,
          decision.thought,
          action,
          input,
          result
        )

        steps += 1
      rescue => e
        @logger.error("[AgentExecutor] Step error: #{e.message}")
        return { response: "Error during execution: #{e.message}" }
      end
    end
  end

  private

  def execute_tool_safely(tool, input)
    Timeout.timeout(STEP_TIMEOUT) do
       result = tool.call(input)
      # input = input.is_a?(Hash) ? input.symbolize_keys : input
      #  input = input.is_a?(Hash) ? input.symbolize_keys : {}
      # result = tool.call(**input)

      if result.is_a?(Hash) && result.key?("error")
        @logger.warn("[AgentExecutor] Tool error: #{result['error']}")
        "Error: #{result['error']}"
      else
        result
      end
    end
  rescue Timeout::Error
    "Tool execution timed out"
  rescue => e
    @logger.error("[AgentExecutor] Tool execution error: #{e.message}")
    "Tool execution failed: #{e.message}"
  end


  # def update_scratchpad(scratchpad, thought, action, input, result)
  #   new_step = <<~STEP
  #   Thought: #{thought || "Using tool"}
  #   Action: #{action}
  #   Action Input: #{format_input(input)}
  #   Observation: #{format_result(result)}

  #   STEP

  #   scratchpad + new_step
  # end
  #
  def update_scratchpad(scratchpad, thought, action, input, result)
    new_step = <<~STEP
    Thought: #{thought || "Using tool"}
    Action: #{action}
    Action Input: #{format_input(input)}
    Observation: #{format_result(result)}

    ---
    STEP

    scratchpad + new_step
  end

  def add_correction(scratchpad, message)
    scratchpad + "\nSYSTEM: #{message}\n"
  end

  def format_input(input)
    input.is_a?(Hash) ? input.to_json : input.to_s
  end

  def format_result(result)
    case result
    when Hash
      compact_result = result.deep_dup

      # Shrink search results in the LLM context to prevent token rate limit errors
      if compact_result.dig(:data, :results).is_a?(Array)
        compact_result[:data][:results].map! do |p|
          p.delete(:image)
          p.delete("image")

          desc = p[:description] || p["description"]
          if desc
            short_desc = desc.to_s.gsub(/<[^>]*>/, " ").squish.truncate(100)
            p[:description] = short_desc if p.key?(:description)
            p["description"] = short_desc if p.key?("description")
          end
          p
        end
      end

      compact_result.to_json
    when Array
      result.to_json
    when String
      result
    else
      result.to_s
    end
  end

  def invalid_decision_error(decision)
    "Invalid decision: #{decision.errors.join(', ')}"
  end
end
