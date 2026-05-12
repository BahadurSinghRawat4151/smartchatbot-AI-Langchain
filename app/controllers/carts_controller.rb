class CartsController < ApplicationController
  # def show
  #   Rails.logger.info("CART DEBUG: #{session[:cart].inspect}")
  #   @cart = session[:cart] || {}
  #   @products = Product.where(id: @cart.keys)
  #   @total = @products.sum { |p| p.price * @cart[p.id.to_s].to_i }
  # end


  def show
  @cart = session[:cart] || {}
  @products = Product.where(id: @cart.keys)
  @total = @products.sum { |p| p.price * @cart[p.id.to_s].to_i }

  respond_to do |format|
    format.html
    format.json do
      render json: {
        items: @products.map { |p|
          {
            id: p.id,
            name: p.name,
            quantity: @cart[p.id.to_s],
            price: p.price
          }
        },
        total: @total
      }
    end
  end
end

  def add_item
    session[:cart] ||= {}
    product_id = params[:product_id].to_s

    session[:cart][product_id] ||= 0
    session[:cart][product_id] += 1

    redirect_to cart_path, notice: "Item added to cart!"
  end

  def remove_item
    session[:cart] ||= {}
    product_id = params[:product_id].to_s
    session[:cart].delete(product_id)

    redirect_to cart_path, notice: "Item removed from cart."
  end
end
