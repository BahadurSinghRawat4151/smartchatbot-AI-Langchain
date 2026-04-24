# app/services/ai/product_loader_service.rb
require 'csv'
class Ai::ProductLoaderService
  # def initialize(csv_path)
  #   @csv_path        = csv_path
  #   @embedding_service = Ai::EmbeddingService.new
  # end
  def initialize(csv_path)
  @csv_path = Rails.root.join(csv_path).to_s
  @embedding_service = Ai::EmbeddingService.new
end

  # def load!
  #   # LangChain CSV loader
  #   loader   = Langchain::Loader.new(@csv_path)
  #   documents = loader.load

  #   puts "📂 Loaded #{documents.size} rows from CSV"

  #   # Group rows by Handle so we can process variants (sizes, colors) together
  #   docs_by_handle = documents.group_by { |doc| doc.metadata[:Handle] }

  #   docs_by_handle.values.each_with_index do |docs, index|
  #     load_product(docs, index)
  #   end

  #   puts "✅ All products loaded with embeddings!"
  # end

  require 'csv'

def load!
  documents = []

  CSV.foreach(@csv_path, headers: true) do |row|
    next if row.nil?

    data = row.to_h

    # 🔥 skip junk rows
    next if data["Handle"].blank?

    documents << {
      metadata: data
    }
  end

  puts "📂 Loaded #{documents.size} valid rows from CSV"

  docs_by_handle = documents.group_by { |doc| doc[:metadata]["Handle"] }

  docs_by_handle.values.each_with_index do |docs, index|
    load_product(docs, index)
  end

  puts "✅ All products loaded with embeddings!"
end

  private

  def load_product(docs, index)
  docs = docs.map { |d| d[:metadata].with_indifferent_access }

  main_doc = docs.find { |d| d[:Title].present? }
  return unless main_doc

  data = parse_document(main_doc)

  variants = docs.map do |d|
    {
      option1: d[:"Option1 Value"],
      option2: d[:"Option2 Value"],
      option3: d[:"Option3 Value"],
      price:   d[:"Variant Price"]
    }.compact_blank
  end.reject(&:empty?)

  data[:specifications] = {
    options: [
      main_doc[:"Option1 Name"],
      main_doc[:"Option2 Name"],
      main_doc[:"Option3 Name"]
    ].compact_blank,
    variants: variants
  }

  product = Product.find_or_initialize_by(name: data[:name])
  product.assign_attributes(data)

  embedding_text = "#{product.to_embedding_text} Variants: #{data[:specifications].to_json}"
  product.embedding = @embedding_service.embed(embedding_text)

  product.save!

  puts "✅ #{index + 1}. #{product.name} loaded!"
rescue => e
  puts "❌ Error loading product #{index + 1}: #{e.message}"
end

  # def parse_document(doc)
  #   # The langchainrb CSV loader provides each row's data in `doc.metadata`.
  #   # The keys are symbols derived from the CSV headers.
  #   # This CSV is a Shopify export, so we map its columns to our Product model.
  #   # metadata = doc.metadata
  #   metadata = doc[:metadata]

  #   {
  #     name:        metadata[:Title],
  #     description: metadata[:"Body (HTML)"],
  #     price:       metadata[:"Variant Price"],
  #     category:    metadata[:"Product Category"],
  #     brand:       metadata[:Vendor],
  #     stock:       0, # Shopify exports stock in a separate file or via API. Defaulting to 0.
  #     specifications: {}
  #   }
  # end
  def parse_document(metadata)
  {
    name:        metadata[:Title],
    description: metadata[:"Body (HTML)"],
    price:       metadata[:"Variant Price"],
    category:    metadata[:"Product Category"],
    brand:       metadata[:Vendor],
    stock:       0,
    specifications: {}
  }
end

  def extract_field(content, field)
    # This fallback is not robust for the Shopify CSV format, so we now rely on metadata.
    content.match(/#{field}:\s*(.+)/i)&.captures&.first&.strip
  end
end
