require "rubygems"
require "redis"

class RedisHAStore

  # this lambda defines how the individual response hashes are merged
  # the default is to merge in reverse-chronological order
  DEFAULT_MERGE_STRATEGY = ->(v) { v
    .sort{ |a,b| a[:_time] <=> b[:_time] }
    .inject({}){ |t,c| t.merge!(c) } }

  # timeout after which a redis connection is considered down. the
  # default is 500ms
  DEFAULT_READ_TIMEOUT  = 500

  # timeout after which a redis that was marked as down is retried
  # the default is 5s
  DEFAULT_RETRY_TIMEOUT = 5000


  attr_accessor :merge_strategy, :read_timeout, :retry_timeout,
    :connections

  def initialize(opts = {})
    @merge_strategy ||= DEFAULT_MERGE_STRATEGY
    @read_timeout   ||= DEFAULT_READ_TIMEOUT
    @retry_timeout  ||= DEFAULT_RETRY_TIMEOUT

    @connections = []
  end

  def add_redis
  end

  def status
  end

  def set(key, data = {})
  end

  def get(key)
  end

end
