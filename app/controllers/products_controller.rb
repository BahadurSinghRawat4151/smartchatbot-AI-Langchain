class ProductsController < ApplicationController
  def index
    # Collection page: Show all products, optionally filtered by category
    # @products = params[:category].present? ? Product.where(category: params[:category]) : Product.all
    @products = Rails.cache.fetch(
      "products:#{params[:category] || 'all'}",
      expires_in: 10.hours
    ) do
      params[:category].present? ?
        Product.where(category: params[:category]).to_a :
        Product.limit(50).to_a
    end
  end

  # def show
  #   @product = Product.find(params[:id])
  # end
  #
  def show
  @product = Rails.cache.fetch("product:#{params[:id]}", expires_in: 1.hour) do
    Product.find(params[:id])
  end
end
end
