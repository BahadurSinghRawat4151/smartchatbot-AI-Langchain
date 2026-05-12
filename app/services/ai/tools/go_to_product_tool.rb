class Ai::Tools::GoToProductTool < Ai::Tools::BaseTool
  def name
    "go_to_product"
  end

  def description
    "Navigate user to a specific product page using product name. Action Input MUST be a JSON object with a single 'query' string key (e.g. {\"query\": \"Product Name\"})."
  end

  def call(input = {})
    query = if input.is_a?(Hash)
              input["query"] || input["product_name"] || input["name"] || input.values.first
    else
              input.to_s
    end

    return error(message: "Product name is required") if query.blank?

    product = Product.find_by("LOWER(name) LIKE ?", "%#{query.downcase.strip}%")

    return error(message: "Product not found") unless product

    success(
      data: {
        url: "/products/#{product.id}"
      },
      message: "Redirect to product page"
    )
  end
end
