# class Ai::Tools::OrderStatusTool
#   extend Langchain::ToolDefinition

#   define_function :order_status,
#     description: "Check order status"

#   def order_status
#     {
#       message: "Order tracking not available yet"
#     }
#   end
# end

class Ai::Tools::OrderStatusTool < Ai::Tools::BaseTool
  def name
    "order_status"
  end

  def description
    "Check order status"
  end

  def call(_input)
    success(
      data: {},
      message: "Order tracking not available yet"
    )
  end
end
