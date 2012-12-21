class RedisHA::Connection < Socket
  attr_accessor :addr, :status, :read_buffer, :write_buffer

  def initialize(redis, pool)
    @write_buffer = ""
    @read_buffer = ""

    super(AF_INET, SOCK_STREAM, 0)

    @pool = pool
    setup(redis)
  end

  def yield_connect
    connect_nonblock(@__addr)
  rescue Errno::EINPROGRESS, Errno::ECONNABORTED, Errno::EINVAL
    nil
  rescue Errno::ECONNREFUSED
    finish(:fail)
  end

  def yield_read
    loop do
      @read_buffer << read_nonblock(1)[0]
    end
  rescue Errno::EAGAIN
    check || raise(Errno::EAGAIN)
  rescue Errno::ENOTCONN
    yield_connect
  rescue Errno::ECONNREFUSED
    finish(:fail)
  end

  def yield_write
    len = write_nonblock(@write_buffer)
    @write_buffer = @write_buffer[len..-1] || ""
  rescue Errno::EPIPE
    yield_connect
  rescue Errno::ECONNREFUSED
    finish(:fail)
  end

  def <<(buf)
    @write_buffer << buf
  end

  def rewind
    @read_buffer = ""
    @write_buffer = ""
    @ready = false
  end

  def wait_read?
    return false if @ready
    @write_buffer.size == 0
  end

  def wait_write?
    return false if @ready
    @write_buffer.size != 0
  end

  def execution_expired
    finish(:fail)
  end

  def ready?
    @ready == true
  end

  def setup(redis)
    addr = [redis.fetch(:port), redis.fetch(:host)]
    addr[1] = (TCPSocket.gethostbyname(addr[1])[4])
    @__addr = Socket.pack_sockaddr_in(*addr)
  end

  def finish(stat)
    @ready = true

    if stat == :success
      @down_since = nil if @status != :up
      @status = :up
    else
      @status = :down
      @down_since = Time.now.to_f
    end
  end

  def check
    #@ready = @read_buffer.size > 3 # FIXPAUL

    if RedisHA::Protocol.peek?(@read_buffer)
      @ready = true
    end

    finish(:success) if @ready
    @ready
  end

  def up_or_retry?
    return true if @status == :up
    return true unless @down_since

    down_diff = Time.now.to_f - @down_since
    return true if down_diff > @pool.retry_timeout
    false
  end

end
