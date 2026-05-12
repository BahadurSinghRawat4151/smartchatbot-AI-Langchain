# # app/services/ai/embedding_service.rb

# class Ai::EmbeddingService
#   class Error < StandardError; end

#   HF_MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
#   HF_URL = "https://router.huggingface.co/hf-inference/models/#{HF_MODEL}/pipeline/feature-extraction"
#   # GROQ_BASE_URL=https://api.groq.com/openai/v1
#   def initialize
#     @api_key = ENV["HUGGINGFACE_API_KEY"]
#   end

#   def embed(text)
#     normalized_text = text.to_s.strip
#     raise Error, "Text for embedding cannot be blank" if normalized_text.blank?
#     raise Error, "HUGGINGFACE_API_KEY is not configured" if @api_key.blank?

#     response = Faraday.post(HF_URL) do |req|
#       req.headers["Authorization"] = "Bearer #{@api_key}"
#       req.headers["Content-Type"] = "application/json"
#       req.body = { inputs: normalized_text }.to_json
#     end

#     unless response.success?
#       raise Error, "Embedding request failed with status #{response.status}: #{extract_error(response.body)}"
#     end

#     unless json_response?(response)
#       raise Error, "Embedding service returned a non-JSON response"
#     end

#     normalize_embedding(JSON.parse(response.body))
#   rescue Error
#     raise
#   rescue JSON::ParserError => e
#     raise Error, "Embedding response could not be parsed: #{e.message}"
#   rescue StandardError => e
#     raise Error, "Embedding request failed: #{e.message}"
#   end

#   private

#   def json_response?(response)
#     response.headers["content-type"].to_s.include?("application/json")
#   end

#   def extract_error(body)
#     JSON.parse(body).to_s
#   rescue JSON::ParserError
#     body.to_s.strip.first(200)
#   end

#   def normalize_embedding(result)
#     vector =
#       case result
#       when Array
#         result.first.is_a?(Array) ? result.first : result
#       when Hash
#         result["embedding"] || result["embeddings"] || result["vector"] || result["vectors"]
#       end

#     vector = vector.first if vector.is_a?(Array) && vector.first.is_a?(Array)
#     vector = Array(vector).map(&:to_f)

#     raise Error, "Embedding response did not contain a usable vector" if vector.empty?

#     vector
#   end
# end


# app/services/ai/embedding_service.rb

class Ai::EmbeddingService
  class Error < StandardError; end

  # ✅ CHANGE: Much faster, smaller model
  HF_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
  HF_URL = "https://router.huggingface.co/hf-inference/models/#{HF_MODEL}/pipeline/feature-extraction"

  def initialize
    @api_key = ENV["HUGGINGFACE_API_KEY"]
  end

  def embed(text)
    normalized_text = text.to_s.strip
    raise Error, "Text for embedding cannot be blank" if normalized_text.blank?
    raise Error, "HUGGINGFACE_API_KEY is not configured" if @api_key.blank?

    response = Faraday.post(HF_URL) do |req|
      req.headers["Authorization"] = "Bearer #{@api_key}"
      req.headers["Content-Type"] = "application/json"
      req.body = { inputs: normalized_text }.to_json
      req.options.timeout = 60  # Still add timeout as safety net
    end

    unless response.success?
      raise Error, "Embedding request failed with status #{response.status}: #{extract_error(response.body)}"
    end

    unless json_response?(response)
      raise Error, "Embedding service returned a non-JSON response"
    end

    normalize_embedding(JSON.parse(response.body))
  rescue Error
    raise
  rescue JSON::ParserError => e
    raise Error, "Embedding response could not be parsed: #{e.message}"
  rescue StandardError => e
    raise Error, "Embedding request failed: #{e.message}"
  end

  private

  def json_response?(response)
    response.headers["content-type"].to_s.include?("application/json")
  end

  def extract_error(body)
    JSON.parse(body).to_s
  rescue JSON::ParserError
    body.to_s.strip.first(200)
  end

  def normalize_embedding(result)
    vector =
      case result
      when Array
        result.first.is_a?(Array) ? result.first : result
      when Hash
        result["embedding"] || result["embeddings"] || result["vector"] || result["vectors"]
      end

    vector = vector.first if vector.is_a?(Array) && vector.first.is_a?(Array)
    vector = Array(vector).map(&:to_f)

    raise Error, "Embedding response did not contain a usable vector" if vector.empty?

    vector
  end
end
