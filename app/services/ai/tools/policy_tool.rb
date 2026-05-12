# class Ai::Tools::PolicyTool
#   extend Langchain::ToolDefinition

#   define_function :policy,
#     description: "Answer store policy related questions"

#   def policy
#     {
#       message: "No policy index yet, provide general guidance"
#     }
#   end
# end

class Ai::Tools::PolicyTool < Ai::Tools::BaseTool
  def name
    "policy"
  end

  def description
    "Answer store policy related questions"
  end

  def call(_input)
    success(
      data: {},
      message: "No policy index yet, provide general guidance"
    )
  end
end
