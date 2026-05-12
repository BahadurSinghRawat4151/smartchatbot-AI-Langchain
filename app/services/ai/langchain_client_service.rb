class Ai::LangchainClientService
  class Error < StandardError; end

    # CHAT_MODEL = "openai/gpt-oss-120b:groq"
    # ROUTER_API_BASE = "https://router.huggingface.co/v1"
    #
    CHAT_MODEL = "openai/gpt-oss-120b" # Groq-supported fast model
  GROQ_API_BASE = "https://api.groq.com/openai/v1"

  def initialize
    @api_key = ENV["GROQ_API_KEY"]
  end

  def chat_llm
    @chat_llm ||= begin
      ensure_api_key!

      Langchain::LLM::OpenAI.new(
        api_key: @api_key,
        llm_options: {
          uri_base: GROQ_API_BASE
        },
        default_options: {
          chat_model: CHAT_MODEL
        }
      )
    end
  end

  private

  def ensure_api_key!
    raise Error, "GROQ_API_KEY is not configured" if @api_key.blank?
  end
end
