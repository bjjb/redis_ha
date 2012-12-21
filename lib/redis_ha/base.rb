class RedisHA::Base

  attr_accessor :pool, :key, :merge_strategy

  def initialize(pool, key)
    @pool = pool
    @key = key
  end

end
