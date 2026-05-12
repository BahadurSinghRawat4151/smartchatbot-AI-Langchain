# app/services/ai/tool_registry.rb
class Ai::ToolRegistry
  def initialize(session:)
    @session = session
  end

  def tools
    @tools ||= [
      Ai::Tools::AddToCartTool.new(session: @session),
      Ai::Tools::CheckoutTool.new(session: @session),
      Ai::Tools::RemoveFromCartTool.new(session: @session),
      Ai::Tools::GetCartItemsTool.new(session: @session),
      Ai::Tools::OrderStatusTool.new,
      Ai::Tools::PolicyTool.new,
      Ai::Tools::ProductSearchTool.new,
      Ai::Tools::GoToCollectionTool.new,
      Ai::Tools::GoToProductTool.new,
      Ai::Tools::GoToCartTool.new,
      Ai::Tools::GoToHomeTool.new
    ]
  end

  # def find(name)
  #   tools.find { |t| t.name == name }
  # end
  #
  #
  def find(name)
  normalized = name.to_s.downcase.strip

  tools.find do |t|
    t.name.to_s.downcase == normalized
  end
end
end
