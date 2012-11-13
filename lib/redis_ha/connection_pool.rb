class RedisHA::ConnectionPool

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
      raise RedisHA::Error.new("you need to call Base.connect first")
    end

    unless @connections.map(&:status).include?(:up)
      raise RedisHA::Error.new("no servers available")
    end
  end

  def method_missing(*msg)
    ensure_connected
    async(*msg)
  end

private

  def async(*msg)
    @semaphore = RedisHA::Semaphore.new(@connections.size)

    @connections.each do |conn|
      conn << [@semaphore, *msg]
    end

    @semaphore.wait

    @connections.map(&:next).tap do
      ensure_connected
    end
  end

  def setup(redis_opts)
    RedisHA::Connection.new(redis_opts,
      :retry_timeout => @retry_timeout,
      :read_timeout => @read_timeout)
  end

end
