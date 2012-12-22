class RedisHA::Set < RedisHA::Base

  # this lambda defines how the individual response hashes are merged
  # the default is set union
  DEFAULT_MERGE_STRATEGY = ->(v) { v.inject(&:|) }

  def add(*items)
    pool.sadd(@key, *items)
    true
  end

  def rem(*items)
    pool.srem(@key, *items)
    true
  end

  def get
    versions = pool.smembers(@key).compact
    merge_strategy[versions]
  end

  def merge_strategy
    @merge_strategy || DEFAULT_MERGE_STRATEGY
  end

end
