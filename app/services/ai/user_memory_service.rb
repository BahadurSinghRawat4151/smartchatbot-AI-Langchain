# app/services/ai/user_memory_service.rb

class Ai::UserMemoryService
  SIMILARITY_THRESHOLD = 0.85     # Used to detect duplicate context
  MIN_RELEVANCE_SCORE  = 0.75     # Minimum similarity score required to include memory in RAG context
  MAX_MEMORIES         = 500      # Max number of conversation turns to store per user in Redis
  TTL                  = 2.hours.to_i # 2 hours expiration for the active session in Redis
  summary_delay = TTL - 30.minutes

  def initialize
    @embedding_service = Ai::EmbeddingService.new
  end

  # Retrieves the most contextually relevant previous messages for the current query.
  # Uses highly efficient in-memory cosine similarity against the active Redis session.
  def relevant_history(user_id:, embedding:, limit: 6)
    key = "user_memory:#{user_id}"
    memories_json = Ai::RedisManager.with { |redis| redis.lrange(key, 0, -1) }
    return [] if memories_json.empty?

    memories = memories_json.map { |m| JSON.parse(m, symbolize_names: true) }

    scored = memories.map do |memory|
      next unless memory[:embedding]
      sim = cosine_similarity(embedding, memory[:embedding])
      memory.merge(similarity: sim)
    end.compact

    # Filter out irrelevant memories
    filtered = scored.select { |m| m[:similarity] >= MIN_RELEVANCE_SCORE }

    # Sort by a combination of relevance and recency
    sorted = filtered.sort_by do |m|
      [
        -m[:similarity],
        -m[:timestamp]
      ]
    end

    sorted.first(limit).map do |m|
      {
        role: m[:role],
        content: m[:content]
      }
    end
  end

  # Retrieves the entire active conversation from Redis and formats them as standard
  # Message objects so they can be rendered seamlessly by the UI alongside DB summaries.
  def get_active_conversation(user_id)
  key = "user_memory:#{user_id}"
  #

  memories_json = Ai::RedisManager.with { |redis| redis.lrange(key, 0, -1) }

  memories_json.map do |m|
    parsed = JSON.parse(m, symbolize_names: true)

    {
      role: parsed[:role],
      content: parsed[:content],
      created_at: parsed[:timestamp] ? Time.at(parsed[:timestamp]) : Time.now
    }
  end
end

  # Saves a single user query and assistant response pair to the active Redis session.
  # def save_turn(user_id:, intent:, query:, query_embedding:, response:)
  #   assistant_embedding = @embedding_service.embed(response)
  #   key = "user_memory:#{user_id}"

  #   Ai::RedisManager.with do |redis|
  #     # Check if this is a brand new conversation session
  #     is_new = redis.exists(key) == 0

  #     user_msg = { role: "user", content: query, embedding: query_embedding, timestamp: Time.now.to_i }.to_json
  #     ast_msg = { role: "assistant", content: response, embedding: assistant_embedding, timestamp: Time.now.to_i }.to_json

  #     # Push messages and maintain a sliding window of MAX_MEMORIES to prevent memory bloat
  #     redis.rpush(key, user_msg)
  #     redis.rpush(key, ast_msg)
  #     redis.ltrim(key, -MAX_MEMORIES, -1)

  #     # If it's a new session, set the expiration and schedule the summary job
  #     if is_new
  #       redis.expire(key, TTL)
  #       # Schedule summary generation right before the 24-hour Redis expiry (at 23.5 hours)
  #       # ConversationSummaryJob.perform_in(1.hours + 30.minutes, user_id)
  #       #
  #       ConversationSummaryJob.perform_in(summary_delay, user_id)
  #     end
  #   end
  # end
  #
  def save_turn(user_id:, intent:, query:, query_embedding:, response:)
  assistant_embedding = @embedding_service.embed(response)
  key = "user_memory:#{user_id}"

  Ai::RedisManager.with do |redis|
    is_new = !redis.exists?(key)

    redis.rpush(key, {
      role: "user",
      content: query,
      embedding: query_embedding,
      timestamp: Time.now.to_i
    }.to_json)

    redis.rpush(key, {
      role: "assistant",
      content: response,
      embedding: assistant_embedding,
      timestamp: Time.now.to_i
    }.to_json)

    redis.ltrim(key, -MAX_MEMORIES, -1)

    # ✅ Always refresh TTL (sliding window)
    redis.expire(key, TTL)

    # ✅ Schedule only once, aligned with TTL
    if is_new
      ConversationSummaryJob.perform_in(TTL - 30.minutes, user_id)
    end
  end
end

  private

  def cosine_similarity(vec1, vec2)
    Langchain::Utils::CosineSimilarity.new(
      Array(vec1).map(&:to_f),
      Array(vec2).map(&:to_f)
    ).calculate_similarity.to_f
  end
end
