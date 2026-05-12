class Product < ApplicationRecord
   unless respond_to?(:neighbors)
    has_neighbors :embedding
   end
#   serialize :images, coder: JSON, type: Array
#  serialize :tags, Array
#
attribute :images, :json, default: []
attribute :tags, :json, default: []
  def self.search_by_embedding(embedding, limit: 5)
    nearest_neighbors(
      :embedding,
      embedding,
      distance: "cosine"
    ).limit(limit)
  end

  def image_url
    images.first
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
      Images: #{images.join(", ")}
    """
  end
end
