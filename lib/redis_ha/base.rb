class RedisHA::Base

  attr_accessor :pool, :key, :merge_strategy

  def initialize(pool, key)
    @pool = pool
    @pool.ensure_connected
    @key = key
  end

end
