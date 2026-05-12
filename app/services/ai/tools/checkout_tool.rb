# class Ai::Tools::CheckoutTool
#   extend Langchain::ToolDefinition

#   define_function :checkout,
#     description: "Proceed to checkout if cart has items"

#   def initialize(session:)
#     @session = session
#   end

#   def checkout
#     cart = @session[:cart] || {}

#     return { message: "Cart is empty" } if cart.empty?

#     {
#       message: "User can proceed to checkout",
#       item_count: cart.values.map(&:to_i).sum
#     }
#   end
# end


# app/services/ai/tools/checkout_tool.rb----real 2

# class Ai::Tools::CheckoutTool < Ai::Tools::BaseTool
#   def initialize(session:)
#     @session = session
#   end

#   def name
#     "checkout"
#   end

#   def description
#     "Proceed to checkout if cart has items"
#   end

#   def call(_input)
#     cart = @session[:cart] || {}

#     return error(message: "Cart is empty") if cart.empty?

#     success(
#       data: { item_count: cart.values.map(&:to_i).sum },
#       message: "User can proceed to checkout"
#     )
#   end
# end
#
#
class Ai::Tools::CheckoutTool < Ai::Tools::BaseTool
  include Rails.application.routes.url_helpers
  def default_url_options
  { host: "unpridefully-noncritical-lenore.ngrok-free.dev" } # change in production
end
  def initialize(session:, user: nil)
    @session = session
    @user = user
  end

  def name
    "checkout"
  end

  def description
    "Create Stripe checkout session and return checkout URL"
  end

  def call(_input)
    cart = @session[:cart] || {}

    return error(message: "Cart is empty") if cart.empty?

    products = Product.find(cart.keys)

    line_items = products.map do |product|
      {
        price_data: {
          currency: "inr",
          product_data: {
            name: product.name
          },
          unit_amount: (product.price * 100).to_i
        },
        quantity: cart[product.id.to_s].to_i
      }
    end

    session = Stripe::Checkout::Session.create(
      payment_method_types: [ "card" ],
      line_items: line_items,
      mode: "payment",
      success_url: checkout_success_url,
      cancel_url: checkout_cancel_url
    )

    success(
      data: {
        url: session.url
      },
      message: "Redirect user to Stripe checkout"
    )
  rescue => e
    error(message: e.message)
  end
end
