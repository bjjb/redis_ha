class RedisHA::Counter < RedisHA::Base

  # this lambda defines how the individual response hashes are merged
  # the default is to select the maximum value
  DEFAULT_MERGE_STRATEGY = ->(v) { v.map(&:to_i).max }

  def incr(n = 1)
    pool.incrby(@key, n)
    true
  end

  def decr(n = 1)
    pool.decrby(@key, n)
    true
  end

  def set(n)
    pool.set(@key, n)
    true
  end

  def get
    versions = pool.get(@key).compact
    merge_strategy[versions]
  end

  def merge_strategy
    @merge_strategy || DEFAULT_MERGE_STRATEGY
  end

end
