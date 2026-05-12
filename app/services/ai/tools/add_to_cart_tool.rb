


class Ai::Tools::AddToCartTool < Ai::Tools::BaseTool
  include Rails.application.routes.url_helpers
  def initialize(session:)
    @session = session
  end

  def name
    "add_to_cart"
  end

  def description
    "Add a product to the user's cart using product_id and quantity and show cart url "
  end

  def call(input)
    product_id = input["product_id"]
    quantity   = (input["quantity"] || 1).to_i
    quantity = [ quantity, 10 ].min


    return error(message: "Missing product_id") unless product_id

    @session[:cart] ||= {}

    current_qty = @session[:cart][product_id.to_s].to_i
    @session[:cart][product_id.to_s] = current_qty + quantity

    success(
      message: "Product added to cart",
      data: { product_id: product_id, quantity: quantity, cart_url: cart_path }
    )
  end
end
