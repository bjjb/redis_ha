require "rubygems"
require "redis"
require "timeout"

Thread.abort_on_exception = true

module RedisHAStore

  def self.default_read_timeout=(t)
    @@default_read_timeout = t
  end

  def self.default_read_timeout
    @@default_read_timeout ||= Connection::DEFAULT_READ_TIMEOUT
  end

  def self.default_retry_timeout=(t)
    @@default_retry_timeout = t
  end

  def self.default_retry_timeout
    @@default_retry_timeout ||= Connection::DEFAULT_RETRY_TIMEOUT
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

  class Connection < Thread

    # timeout after which a redis connection is considered down. the
    # default is 500ms
    DEFAULT_READ_TIMEOUT  = 0.5

    # timeout after which a redis that was marked as down is retried
    # the default is 5s
    DEFAULT_RETRY_TIMEOUT = 5

    attr_accessor :status, :read_timeout, :retry_timeout

    def initialize(redis_opts, opts = {})
      @read_timeout   ||= RedisHAStore.default_read_timeout
      @retry_timeout  ||= RedisHAStore.default_retry_timeout

      @redis_opts = redis_opts
      @opts = opts
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

    attr_accessor :connections

    def initialize
      @connections  = []
      @connected = false
    end

    def connect(*conns)
      conns.each do |conn|
        @connections << RedisHAStore::Connection.new(conn)
      end

      run_sync(:connect)
      @connected = true
    end

  private

    def run_sync(*msg)
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
