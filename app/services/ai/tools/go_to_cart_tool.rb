class Ai::Tools::GoToCartTool < Ai::Tools::BaseTool
  def name
    "go_to_cart"
  end

  def description
    "Navigate user to cart page"
  end

  def call(input = {})
    success(
  data: {
    action: "navigate",
    path: "/cart"
  },
  message: "Navigating to cart"
)
  end
end
