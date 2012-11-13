require "rubygems"
require "redis"
require "timeout"

module RedisHAStore

  # this lambda defines how the individual response hashes are merged
  # the default is to merge in reverse-chronological order
  DEFAULT_MERGE_STRATEGY = ->(v) { v
    .sort{ |a,b| a[:_time] <=> b[:_time] }
    .inject({}){ |t,c| t.merge!(c) } }

  # timeout after which a redis connection is considered down. the
  # default is 500ms
  DEFAULT_READ_TIMEOUT  = 0.5

  # timeout after which a redis that was marked as down is retried
  # the default is 5s
  DEFAULT_RETRY_TIMEOUT = 5

  class Connection

    attr_accessor :status, :read_timeout, :retry_timeout

    def initialize(redis_opts, opts = {})
      @read_timeout   ||= DEFAULT_READ_TIMEOUT
      @retry_timeout  ||= DEFAULT_RETRY_TIMEOUT

      @redis_opts = redis_opts
      @opts = opts

      connect
    end

  private

    def connect
      Timeout::timeout(@read_timeout) do
        @redis = Redis.new(@redis_opts)
        mark_as_up if @redis.ping
      end
    rescue Redis::CannotConnectError
      mark_as_down
    rescue Timeout::Error
      mark_as_down
    end

    def mark_as_down
      @status = :down
      @down_since = Time.now.to_i
    end

    def mark_as_up
      @status = :up
      @down_since = nil
    end

    def down_since
      @down_since ||= Time.now.to_i
    end

  end

  class HashMap
    attr_accessor :merge_strategy, :connections

    def initialize(prefix, opts = {})
      @merge_strategy ||= DEFAULT_MERGE_STRATEGY

      @redis_prefix = prefix
      @connections  = []
    end

    def add_redis(opts = {})
      @connections << RedisHAStore::Connection.new(opts)
    end

    def status
    end

    def set(key, data = {})
    end

    def get(key)
    end

  end

end
