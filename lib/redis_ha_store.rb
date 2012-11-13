require "rubygems"
require "redis"
require "timeout"

Thread.abort_on_exception = true

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

  private

    def invoke_unsafe(*msg)
      @semaphore = Semaphore.new(@connections.size)

      @connections.each do |conn|
        conn.run_async(@semaphore, *msg)
      end

      @semaphore.wait
    end

    def ensure_connected
      return if @connected
      raise "you need to invoke Base.connect first"
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
      @read_timeout = opts[:read_timeout]
      @retry_timeout = opts[:retry_timeout]

      @redis_opts = redis_opts
      @queue = Queue.new

      super do
        self.run_sync
      end
    end

    def run_sync
      while job = @queue.pop
        semaphore, *msg = job
        send(*msg)
        semaphore.decrement
      end
    end

    def run_async(*msg)
      @queue << msg
    end

  private

    def connect
      with_timeout_and_check do
        @redis = Redis.new(@redis_opts)
        @redis.ping
      end
    end

    def call(*msg)
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

  end

  class HashMap < Base

    # this lambda defines how the individual response hashes are merged
    # the default is to merge in reverse-chronological order
    DEFAULT_MERGE_STRATEGY = ->(v) { v
      .sort{ |a,b| a[:_time] <=> b[:_time] }
      .inject({}){ |t,c| t.merge!(c) } }

    attr_accessor :merge_strategy, :connections

    def initialize(opts = {})
      @merge_strategy ||= DEFAULT_MERGE_STRATEGY

      super()
    end

    def set(key, data = {})
      ensure_connected

      run_sync(:call, :set, key, "fnord")
    end

    def get(key)
      ensure_connected
    end

  end


end
