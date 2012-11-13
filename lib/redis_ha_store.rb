require "rubygems"
require "redis"
require "timeout"

module RedisHAStore

  class Error < StandardError
  end

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
      @connected = true

      conns.each do |conn|
        @connections << setup(conn)
      end

      async(:connect)
    end

    def ensure_connected
      unless @connected
        raise Error.new("you need to call Base.connect first")
      end

      unless @connections.map(&:status).include?(:up)
        raise Error.new("no servers available")
      end
    end

    def method_missing(*msg)
      ensure_connected
      async(*msg)
    end

  private

    def async(*msg)
      @semaphore = Semaphore.new(@connections.size)

      @connections.each do |conn|
        conn << [@semaphore, *msg]
      end

      @semaphore.wait

      @connections.map(&:next).tap do
        ensure_connected
      end
    end

    def setup(redis_opts)
      Connection.new(redis_opts,
        :retry_timeout => @retry_timeout,
        :read_timeout => @read_timeout)
    end

  end

  class Connection < Thread

    attr_accessor :status, :buffer

    def initialize(redis_opts, opts = {})
      self.abort_on_exception = true

      @read_timeout = opts[:read_timeout]
      @retry_timeout = opts[:retry_timeout]
      @redis_opts = redis_opts

      @queue = Queue.new
      @buffer = Array.new
      @lock = Mutex.new

      super do
        run
      end
    end

    def next
      @lock.synchronize do
        @buffer.shift
      end
    end

    def <<(msg)
      @queue << msg
    end

  private

    def run
      while job = @queue.pop
        semaphore, *msg = job

        @lock.synchronize do
          @buffer << send(*msg)
        end

        semaphore.decrement
      end
    end

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
      ret = Timeout::timeout(@read_timeout) do
        yield
      end
    rescue Redis::CannotConnectError
      mark_as_down
    rescue Timeout::Error
      mark_as_down
    else
      mark_as_up; ret
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

    attr_accessor :pool, :key, :merge_strategy

    def initialize(pool, key)
      @pool = pool
      @pool.ensure_connected
      @key = key
    end

  end

  class HashMap < Base

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


end
