# app/jobs/conversation_summary_job.rb

class ConversationSummaryJob
  include Sidekiq::Job

  # This job runs approximately 30 minutes before a user's active Redis session expires (at the 10-hour mark).
  # It extracts the entire short-term conversation from Redis, uses the LLM to summarize the interaction,
  # and saves that summary back to the permanent `messages` table in the database.
  def perform(user_id)
    key = "user_memory:#{user_id}"

    memories_json = Ai::RedisManager.with { |redis| redis.lrange(key, 0, -1) }
    return if memories_json.empty?

    # Reconstruct the raw conversational transcript
    conversation = memories_json.map do |m|
      parsed = JSON.parse(m, symbolize_names: true)
      "#{parsed[:role]}: #{parsed[:content]}"
    end.join("\n")

    # Ask the LLM to compress/summarize the context
    client = Ai::LangchainClientService.new.chat_llm
    prompt = "Briefly summarize the key points, products discussed, and user preferences from the following interaction history:\n\n#{conversation}"

    response = client.chat(messages: [ { role: "user", content: prompt } ])
    summary_text = response.chat_completion.to_s.strip

        # Persist summarized context out of Redis to permanent database storage.
        # By assigning role 'summary', it helps the LLM distinguish compressed history from active dialog.
        # Message.create!(user_id: user_id, role: "summary", content: "Conversation Summary: #{summary_text}")
        Message.create!(user_id: user_id, ai_summary: "Conversation Summary: #{summary_text}")
  end
end
