class Product < ApplicationRecord
  has_neighbors :embedding

  def self.search_by_embedding(embedding, limit: 5)
    nearest_neighbors(
      :embedding,
      embedding,
      distance: "cosine"
    ).limit(limit)
  end

  # Convert product to text for embedding
  def to_embedding_text
    """
      Product: #{name}
      Brand: #{brand}
      Category: #{category}
      Price: #{price}
      Description: #{description}
      Specifications: #{specifications}
    """
  end
end
