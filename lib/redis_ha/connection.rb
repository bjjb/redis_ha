class RedisHA::Connection < Thread

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
  rescue Exception => e
    @status = :down
    @down_since = Time.now.to_f
    return nil
  else
    @down_since = nil if @status != :up
    @status = :up
    return ret
  end

  def up_or_retry?
    return true if @status == :up
    return true unless @down_since

    down_diff = Time.now.to_f - @down_since
    return true if down_diff > @retry_timeout
    false
  end

end

