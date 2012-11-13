require "rubygems"
require "redis"
require "timeout"

module RedisHAStore

  class Semaphore

    def initialize(n)
      @lock = Mutex.new
      @n = n
    end

    def decrement
      @lock.synchronize do
        @n -= 1
      end
    end

    def wait
      sleep(0.001) while @n != 0
    end

  end

  class ConnectionPool

    # timeout after which a redis connection is considered down. the
    # default is 500ms
    DEFAULT_READ_TIMEOUT  = 0.5

    # timeout after which a redis that was marked as down is retried
    # the default is 5s
    DEFAULT_RETRY_TIMEOUT = 5

    attr_accessor :status, :connections, :read_timeout, :retry_timeout

    def initialize
      @read_timeout  = DEFAULT_READ_TIMEOUT
      @retry_timeout = DEFAULT_RETRY_TIMEOUT

      @connections = []
      @connected = false
    end

    def connect(*conns)
      conns.each do |conn|
        @connections << new_connection(conn)
      end

      invoke_unsafe(:connect)
      @connected = true
    end

    def invoke(*msg)
      ensure_connected
      invoke_unsafe(*msg)
    end

    def ensure_connected
      return if @connected
      raise "you need to invoke Base.connect first"
    end

    def method_missing(*msg)
      invoke(*msg)
    end

  private

    def invoke_unsafe(*msg)
      @semaphore = Semaphore.new(@connections.size)

      @connections.each do |conn|
        conn.invoke(@semaphore, *msg)
      end

      @semaphore.wait
    end

    def new_connection(redis_opts)
      Connection.new(redis_opts, default_opts)
    end

    def default_opts
      {
        :retry_timeout => @retry_timeout,
        :read_timeout => @read_timeout
      }
    end

  end

  class Connection < Thread

    attr_accessor :status

    def initialize(redis_opts, opts = {})
      self.abort_on_exception = true

      @read_timeout = opts[:read_timeout]
      @retry_timeout = opts[:retry_timeout]

      @redis_opts = redis_opts
      @queue = Queue.new

      super do
        self.run
      end
    end

    def run
      while job = @queue.pop
        semaphore, *msg = job
        send(*msg)
        semaphore.decrement
      end
    end

    def invoke(*msg)
      @queue << msg
    end

  private

    def connect
      with_timeout_and_check do
        @redis = Redis.new(@redis_opts)
        @redis.ping
      end
    end

    def method_missing(*msg)
      with_timeout_and_check do
        @redis.send(*msg)
      end
    end

    def with_timeout_and_check(&block)
      return nil unless up_or_retry?
      with_timeout(&block)
    end

    def with_timeout
      result = Timeout::timeout(@read_timeout) do
        yield
      end
      result
    rescue Redis::CannotConnectError
      mark_as_down
    rescue Timeout::Error
      mark_as_down
    end

    def up_or_retry?
      return true if @status == :up
      return true unless @down_since

      down_diff = Time.now.to_f - @down_since
      return true if down_diff > @retry_timeout
      false
    end

    def mark_as_down
      @status = :down
      @down_since = Time.now.to_f
    end

    def mark_as_up
      return if @status == :up
      @status = :up
      @down_since = nil
    end

  end

  class Base

    attr_accessor :pool

    def initialize(pool)
      @pool = pool
      @pool.ensure_connected
    end

  private

    def invoke(*msg)
      @pool.invoke(*msg)
    end

  end

  class HashMap < Base

    # this lambda defines how the individual response hashes are merged
    # the default is to merge in reverse-chronological order
    DEFAULT_MERGE_STRATEGY = ->(v) { v
      .sort{ |a,b| a[:_time] <=> b[:_time] }
      .inject({}){ |t,c| t.merge!(c) } }

    attr_accessor :merge_strategy, :key

    def initialize(pool, key, opts = {})
      @merge_strategy = DEFAULT_MERGE_STRATEGY
      @key = key
      super(pool)
    end

    def set(data = {})
      invoke(:set, @key, "fnord")
    end

    def get(key)
      invoke(:get, @key)
    end

  end


end
