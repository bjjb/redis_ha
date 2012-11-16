class RedisHA::Connection < Thread

  POLL_INTERVAL = 0.01

  attr_accessor :status, :buffer

  def initialize(redis_opts, opts = {})
    self.abort_on_exception = true

    @read_timeout = opts[:read_timeout]
    @retry_timeout = opts[:retry_timeout]
    @redis_opts = redis_opts

    @queue = Array.new
    @queue_lock = Mutex.new
    @buffer = Array.new
    @buffer_lock = Mutex.new

    super do
      run
    end
  end

  def next
    @buffer_lock.synchronize do
      @buffer.shift
    end
  end

  def <<(msg)
    @buffer_lock.synchronize do
      @queue << msg
    end
  end

private

  def run
    while job = pop
      semaphore, *msg = job

      @buffer_lock.synchronize do
        @buffer << send(*msg)
      end

      semaphore.decrement
    end
  end

  def pop
    loop do
      sleep(POLL_INTERVAL) while @queue.size < 1
      @queue_lock.synchronize do
        job = @queue.shift
        return job if job
      end
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

