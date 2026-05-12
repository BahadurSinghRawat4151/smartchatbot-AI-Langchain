# app/services/ai/policy_loader_service.rb
require "csv"

class Ai::PolicyLoaderService
  def initialize(csv_path)
    @csv_path = Rails.root.join(csv_path).to_s
    @embedding_service = Ai::EmbeddingService.new
  end

  def load!
    documents = load_documents

    puts "📂 Loaded #{documents.size} policies from CSV"

    loaded = 0
    failed = 0

    documents.each_with_index do |metadata, index|
      load_policy(metadata, index)
      loaded += 1
    rescue StandardError => e
      failed += 1
      puts "❌ Policy #{index + 1} failed: #{e.message}"
    end

    puts "✅ Loaded #{loaded} policies"
    puts "⚠️ Failed #{failed} policies" if failed.positive?
  end

  private

  # ---------------------------
  # Load CSV
  # ---------------------------
  def load_documents
    CSV.foreach(@csv_path, headers: true).filter_map do |row|
      data = row.to_h
      next if data["Title"].blank? || data["Content"].blank?

      data.with_indifferent_access
    end
  end

  # ---------------------------
  # Create Policy + Chunks
  # ---------------------------
  def load_policy(metadata, index)
    policy = Policy.find_or_initialize_by(title: metadata[:Title])

    policy.assign_attributes(
      category: metadata[:Category]
    )

    policy.save!

    # 🔥 important: recreate chunks
    policy.policy_chunks.delete_all

    chunks = chunk_text(metadata[:Content])

    chunks.each_with_index do |chunk_text, i|
      embedding = embed(chunk_text)

      policy.policy_chunks.create!(
        content: chunk_text,
        chunk_index: i,
        embedding: embedding
      )
    end

    puts "✅ #{index + 1}. #{policy.title} (#{chunks.size} chunks)"
  end

  # ---------------------------
  # 🔥 HYBRID CHUNKING
  # ---------------------------
  def chunk_text(text)
    return [] if text.blank?

    # 1️⃣ Lexical split (paragraphs)
    paragraphs = text.split(/\n{2,}/)

    chunks = []

    paragraphs.each do |para|
      # 2️⃣ Semantic split (sentence grouping)
      sentences = para.split(/(?<=[.!?])\s+/)

      buffer = ""

      sentences.each do |sentence|
        if buffer.length + sentence.length > max_chunk_size
          chunks << buffer.strip if buffer.present?
          buffer = sentence
        else
          buffer += " #{sentence}"
        end
      end

      chunks << buffer.strip if buffer.present?
    end

    # 3️⃣ Add overlap (context continuity)
    add_overlap(chunks)
  end

  def max_chunk_size
    500 # tune based on model (tokens approx)
  end

  def overlap_size
    50
  end

  def add_overlap(chunks)
    overlapped = []

    chunks.each_with_index do |chunk, i|
      prev = chunks[i - 1]

      if prev
        overlap = prev.split.last(overlap_size).join(" ")
        overlapped << "#{overlap} #{chunk}"
      else
        overlapped << chunk
      end
    end

    overlapped
  end

  # ---------------------------
  # Embedding
  # ---------------------------
  def embed(text)
    vector = @embedding_service.embed(text)

    vector.map(&:to_f) # ensure pgvector compatibility
  rescue StandardError => e
    puts "⚠️ Embedding failed: #{e.message}"
    []
  end
end
