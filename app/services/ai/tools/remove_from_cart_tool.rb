class Ai::Tools::RemoveFromCartTool < Ai::Tools::BaseTool
  include Rails.application.routes.url_helpers
  def initialize(session:)
    @session = session
  end

  def name
    "remove_from_cart"
  end

  def description
    "Remove a product from the user's cart using product_id and quantity and show cart url "
  end

  def call(input)
    product_id = input["product_id"]
    name       = input["name"]

    if product_id.blank? && name.present?
      product_id = find_product_id_from_cart(name)
    end

    return error(message: "Product not found in cart") unless product_id

    @session[:cart] ||= {}

    current_qty = @session[:cart][product_id.to_s].to_i
    return error(message: "Product not in cart") if current_qty.zero?

    quantity = (input["quantity"] || 1).to_i
    new_qty = [ current_qty - quantity, 0 ].max

    @session[:cart][product_id.to_s] = new_qty

    success(
      message: "Product removed from cart",
      data: {
        product_id: product_id,
        quantity_removed: current_qty - new_qty,
        cart_url: cart_path
      }
    )
  end

  def find_product_id_from_cart(name)
    cart = @session[:cart] || {}

    cart.keys.find do |id|
      product = Product.find_by(id: id)
      product&.name&.downcase&.include?(name.downcase)
    end
  end
end


# class Ai::Tools::AddToCartTool < Ai::Tools::BaseTool
#   include Rails.application.routes.url_helpers
#   def initialize(session:)
#     @session = session
#   end

#   def name
#     "add_to_cart"
#   end

#   def description
#     "Add a product to the user's cart using product_id and quantity and show cart url "
#   end

#   def call(input)
#     product_id = input["product_id"]
#     quantity   = (input["quantity"] || 1).to_i
#     quantity = [ quantity, 10 ].min


#     return error(message: "Missing product_id") unless product_id

#     @session[:cart] ||= {}

#     current_qty = @session[:cart][product_id.to_s].to_i
#     @session[:cart][product_id.to_s] = current_qty + quantity

#     success(
#       message: "Product added to cart",
#       data: { product_id: product_id, quantity: quantity, cart_url: cart_path }
#     )
#   end
# end
