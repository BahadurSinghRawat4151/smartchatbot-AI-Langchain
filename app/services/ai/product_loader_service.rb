# app/services/ai/product_loader_service.rb
require "csv"

class Ai::ProductLoaderService
  def initialize(csv_path)
    @csv_path = Rails.root.join(csv_path).to_s
    @embedding_service = Ai::EmbeddingService.new
  end

  def load!
    documents = load_documents

    puts "📂 Loaded #{documents.size} valid rows from CSV"

    loaded_count = 0
    error_count = 0

    documents.group_by { |doc| doc[:metadata]["Handle"] }.values.each_with_index do |docs, index|
      load_product(docs, index)
      loaded_count += 1
    rescue StandardError => e
      error_count += 1
      puts "❌ Error loading product #{index + 1}: #{e.message}"
    end

    puts "✅ Loaded #{loaded_count} products with embeddings"
    puts "⚠️ Failed #{error_count} products" if error_count.positive?
  end

  private

  def load_documents
    CSV.foreach(@csv_path, headers: true).filter_map do |row|
      next if row.nil?

      data = row.to_h
      next if data["Handle"].blank?

      { metadata: data }
    end
  end

  def load_product(docs, index)
    docs = docs.map { |doc| doc[:metadata].with_indifferent_access }
    main_doc = docs.find { |doc| doc[:Title].present? }
    return unless main_doc

    data = parse_document(main_doc)
    data[:images] = image_urls_for(docs)
    data[:specifications] = specifications_for(docs, main_doc)

    product = Product.find_or_initialize_by(name: data[:name])
    product.assign_attributes(data)

    product.embedding = embed_product(product, data)
    product.save!

    puts "✅ #{index + 1}. #{product.name} loaded"
  end

  def parse_document(metadata)
    {
      name: metadata[:Title],
      description: metadata[:"Body (HTML)"],
      price: metadata[:"Variant Price"],
      category: metadata[:"Product Category"],
      brand: metadata[:Vendor],
      tags: metadata[:Tags],
      product_type: metadata[:Type],
      stock: stock_for(metadata),
      specifications: {}
    }
  end

  def image_urls_for(docs)
    docs.map { |doc| doc[:"Image Src"] }.compact_blank.uniq
  end

  def specifications_for(docs, main_doc)
    variants = docs.map do |doc|
      {
        option1: doc[:"Option1 Value"],
        option2: doc[:"Option2 Value"],
        option3: doc[:"Option3 Value"],
        price: doc[:"Variant Price"]
      }.compact_blank
    end.reject(&:empty?)

    {
      options: [
        main_doc[:"Option1 Name"],
        main_doc[:"Option2 Name"],
        main_doc[:"Option3 Name"]
      ].compact_blank,
      variants: variants
    }
  end

  def stock_for(metadata)
    (
      metadata[:"Variant Inventory Qty"].presence ||
      metadata[:"Variant Inventory Quantity"].presence ||
      metadata[:Stock].presence ||
      metadata[:"Shop location"].presence ||
      0
    ).to_i
  end

  def embed_product(product, data)
    embedding_text = "#{product.to_embedding_text} Variants: #{data[:specifications].to_json}"
    @embedding_service.embed(embedding_text)
  rescue StandardError => e
    puts "⚠️ Embedding failed for #{product.name}: #{e.message}"
    []
  end
end
