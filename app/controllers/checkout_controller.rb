class CheckoutController < ApplicationController
  def create
    cart = session[:cart] || {}
     return render json: { error: "Your cart is empty!" }, status: 400 if cart.empty?


    products = Product.where(id: cart.keys)
    total_amount = products.sum do |p|
      p.price * cart[p.id.to_s].to_i
    end

    if total_amount > 9999999
      return redirect_to cart_path, alert: "Cart total too large. Reduce quantity."
    end

    line_items = products.map do |product|
      {
        price_data: {
          currency: "inr", # Matching the INR used in your chat_service.rb
          product_data: {
            name: product.name,
            description: product.description.to_s.truncate(200)
          }.compact_blank,
          unit_amount: (product.price * 100).to_i # Stripe expects amounts in cents/paise
        },
        quantity: cart[product.id.to_s].to_i
      }
    end

    stripe_session = Stripe::Checkout::Session.create({
      payment_method_types: [ "card" ],
      line_items: line_items,
      mode: "payment",
      success_url: checkout_success_url,
      cancel_url: checkout_cancel_url
    })
     render json: { url: stripe_session.url }
    # redirect_to stripe_session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("STRIPE ERROR: #{e.message}")
    redirect_to cart_path, alert: "Stripe error: #{e.message}", status: 422
  end

  def success
    session[:cart] = {} # Clear cart on success
  end

  def cancel
  end
end
