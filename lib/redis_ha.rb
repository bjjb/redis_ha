require "rubygems"
require "redis"
require "timeout"

module RedisHA
  class Error < StandardError
  end
end

require "redis_ha/base"
require "redis_ha/semaphore"
require "redis_ha/connection"
require "redis_ha/connection_pool"
require "redis_ha/hash_map"
