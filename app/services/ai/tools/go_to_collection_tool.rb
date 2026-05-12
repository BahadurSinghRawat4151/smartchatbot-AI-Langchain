class Ai::Tools::GoToCollectionTool < Ai::Tools::BaseTool
  def name
    "go_to_collection"
  end

  def description
    "Navigate user to a product collection/category page. Action Input MUST be a JSON object with a single 'query' string key. If the user does not specify a specific category, use {\"query\": \"all\"}."
  end

  def call(input = {})
    query = if input.is_a?(Hash)
              input["query"] || input["category"] || input["collection_name"] || input.values.first
    else
              input.to_s
    end

    url = "/products"

    # If the user asked for a specific category, append it as a URL parameter
    if query.present? && !query.match?(/all/i)
      url += "?category=#{CGI.escape(query.strip)}"
    end

    success(
      data: {
        url: url
      },
      message: "Redirect to collection page"
    )
  end
end
