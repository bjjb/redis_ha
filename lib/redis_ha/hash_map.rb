class RedisHA::HashMap < RedisHA::Base

  # this lambda defines how the individual response hashes are merged
  # the default is to merge in reverse-chronological order
  DEFAULT_MERGE_STRATEGY = ->(v) { v
    .sort{ |a,b| a[:_time] <=> b[:_time] }
    .inject({}){ |t,c| t.merge!(c) } }

  def set(data = {})
    pool.set(@key, "fnord")
  end

  def get(key)
    pool.get(@key)
  end

  def merge_strategy
    @merge_strategy || DEFAULT_MERGE_STRATEGY
  end

end
