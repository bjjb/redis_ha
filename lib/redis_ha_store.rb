require "rubygems"
require "redis"

class RedisHAStore

  # timeout after which a redis connection is considered
  # down (500ms)
  READ_TIMEOUT  = 500

  # timeout after which a redis that was marked as down
  # is retried
  RETRY_TIMEOUT = 5000 # 5s

  def initialize(opts)
  end

  def add_redis
  end

  def status
  end

  def set(key, data = {})
  end

  def get(key)
  end

private

end
