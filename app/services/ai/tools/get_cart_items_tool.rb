class Ai::Tools::GetCartItemsTool < Ai::Tools::BaseTool
  def initialize(session:)
    @session = session
  end

  def name
    "get_cart_items"
  end

  def description
    "Returns all items currently in the user's cart with product_id and name"
  end

  def call(_input = {})
    cart = @session[:cart] || {}

    items = cart.map do |product_id, qty|
      product = Product.find_by(id: product_id)

      {
        product_id: product_id,
        name: product&.name,
        quantity: qty
      }
    end

    success(data: { items: items })
  end
end
