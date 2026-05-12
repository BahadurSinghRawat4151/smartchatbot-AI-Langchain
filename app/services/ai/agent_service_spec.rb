# # spec/services/ai/agent_service_spec.rb

# describe Ai::AgentService do
#   let(:session) { create(:session) }
#   let(:service) { described_class.new(session: session) }

#   describe "#run" do
#     it "returns final answer for simple query" do
#       query = "what are your store policies?"

#       result = service.run(query)

#       expect(result).to be_a(String)
#       expect(result).not_to include("Action:")
#       expect(result).not_to include("Thought:")
#     end

#     it "searches for products when needed" do
#       query = "show me laptops under $1000"

#       result = service.run(query)

#       # Should not contain action format
#       expect(result).not_to match(/^Thought:/)
#       expect(result).to be_present
#     end

#     it "raises error on blank query" do
#       expect { service.run("") }.to raise_error(ArgumentError)
#     end

#     it "handles long queries" do
#       long_query = "x" * 600
#       expect { service.run(long_query) }.to raise_error(ArgumentError)
#     end
#   end
# end

# # spec/services/ai/agent_executor_spec.rb

# describe Ai::AgentExecutor do
#   let(:agent) { instance_double(Ai::Agent) }
#   let(:registry) { instance_double(Ai::ToolRegistry) }
#   let(:executor) { described_class.new(agent: agent, tool_registry: registry) }

#   describe "#run" do
#     it "returns final answer when agent decides final_answer" do
#       decision = Decision.final_answer("Here are the results")
#       allow(agent).to receive(:decide).and_return(decision)

#       result = executor.run("test query")

#       expect(result).to eq("Here are the results")
#     end

#     it "executes tool when agent decides tool action" do
#       search_tool = instance_double(Ai::Tools::ProductSearchTool)
#       allow(search_tool).to receive(:name).and_return("product_search")
#       allow(registry).to receive(:find).with("product_search").and_return(search_tool)

#       decision1 = Decision.new(
#         action: "product_search",
#         input: { query: "laptop" }
#       )
#       decision2 = Decision.final_answer("Found laptops")

#       allow(agent).to receive(:decide).and_return(decision1, decision2)
#       allow(search_tool).to receive(:call).and_return([ { name: "Laptop X" } ])

#       result = executor.run("find laptops")

#       expect(result).to eq("Found laptops")
#       expect(search_tool).to have_received(:call)
#     end

#     it "stops after max steps" do
#       decisions = 6.times.map do
#         Decision.new(action: "product_search", input: {})
#       end

#       allow(agent).to receive(:decide).and_return(*decisions)
#       allow(registry).to receive(:find).and_return(nil)

#       result = executor.run("test")

#       expect(result).to include("Unknown tool")
#     end
#   end
# end

# # spec/services/ai/agent_spec.rb

# describe Ai::Agent do
#   let(:llm) { instance_double(Langchain::Chat) }
#   let(:tools) { [ double(name: "product_search", description: "Search products") ] }
#   let(:agent) { described_class.new(llm: llm, tools: tools) }

#   describe "#decide" do
#     it "parses final answer correctly" do
#       response = double(
#         raw: {
#           "choices" => [
#             { "message" => { "content" => "Final Answer: Here are the results" } }
#           ]
#         }
#       )
#       allow(llm).to receive(:chat).and_return(response)

#       decision = agent.decide(query: "test", scratchpad: "")

#       expect(decision.action).to eq("final_answer")
#       expect(decision.input).to eq("Here are the results")
#     end

#     it "parses tool action correctly" do
#       response = double(
#         raw: {
#           "choices" => [
#             {
#               "message" => {
#                 "content" => "Thought: Need to search\nAction: product_search\nAction Input: {\"query\": \"shoes\"}"
#               }
#             }
#           ]
#         }
#       )
#       allow(llm).to receive(:chat).and_return(response)

#       decision = agent.decide(query: "find shoes", scratchpad: "")

#       expect(decision.action).to eq("product_search")
#       expect(decision.input).to eq({ "query" => "shoes" })
#       expect(decision.thought).to include("search")
#     end

#     it "handles JSON parsing errors gracefully" do
#       response = double(
#         raw: {
#           "choices" => [
#             {
#               "message" => {
#                 "content" => "Thought: Test\nAction: product_search\nAction Input: invalid json"
#               }
#             }
#           ]
#         }
#       )
#       allow(llm).to receive(:chat).and_return(response)

#       decision = agent.decide(query: "test", scratchpad: "")

#       expect(decision.valid?).to be true
#       expect(decision.input).to include("invalid json")
#     end
#   end
# end
