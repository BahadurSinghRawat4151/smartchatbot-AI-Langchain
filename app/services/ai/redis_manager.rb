# app/services/ai/redis_manager.rb
require "redis"
require "connection_pool"

class Ai::RedisManager
  def self.with(&block)
    @pool ||= initialize_pool
    @pool.with(&block)
  end

  def self.initialize_pool
    # 1. If the initializer loaded successfully, use the global constant
    return ::REDIS_POOL if defined?(::REDIS_POOL)

    # 2. Otherwise, auto-initialize safely without relying on the global constant
    config_path = Rails.root.join("config", "redis.yml")

    redis_config = if File.exist?(config_path)
      YAML.safe_load(ERB.new(File.read(config_path)).result)[Rails.env] || {}
    else
      {}
    end

    ConnectionPool.new(size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i, timeout: 5) do
      Redis.new(
        host: redis_config["host"] || "localhost",
        port: redis_config["port"] || 6379,
        db: redis_config["db"] || 0,
        password: redis_config["password"]
      )
    end
  end
end
