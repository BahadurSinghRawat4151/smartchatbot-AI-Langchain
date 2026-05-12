# config/initializers/redis.rb

require "redis"

# Load Redis configuration from config/redis.yml
redis_config_file = Rails.root.join("config", "redis.yml")
redis_config = YAML.safe_load(ERB.new(File.read(redis_config_file)).result)[Rails.env]

Rails.application.config.redis_config = redis_config

# Create Redis connection pool
REDIS_POOL = ConnectionPool.new(size: 5, timeout: 5) do
  Redis.new(
    host: redis_config["host"],
    port: redis_config["port"],
    db: redis_config["db"],
    password: redis_config["password"]
  )
end

# For Sidekiq configuration
Sidekiq.configure_server do |config|
  config.redis = {
    url: "redis://#{redis_config['host']}:#{redis_config['port']}/#{redis_config['db']}#{":#{redis_config['password']}" if redis_config['password'].present?}",
    size: 10
  }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: "redis://#{redis_config['host']}:#{redis_config['port']}/#{redis_config['db']}#{":#{redis_config['password']}" if redis_config['password'].present?}",
    size: 5
  }
end
