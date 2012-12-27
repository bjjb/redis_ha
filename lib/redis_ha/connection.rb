class RedisHA::Connection < Socket
  attr_accessor :addr, :status, :read_buffer, :write_buffer

  def initialize(redis, pool)
    @write_buffer = ""
    @read_buffer = ""
    @response_offset = 0

    super(AF_INET, SOCK_STREAM, 0)

    @redis = redis
    @pool = pool
    setup(redis)
  end

  def yield_connect
    if @redis[:db] && !@db_selected
      @db_selected = true
      @response_offset += 1
      self << RedisHA::Protocol.request("select", @redis[:db])
    end

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
    @ready = false
    @response_offset -= 0
  end

  def next
    @response_offset -= 1
    RedisHA::Protocol.parse(@read_buffer)
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
    if @ready && @response_offset > 0
      self.next; @ready = false; check
    end

    !!@ready
  end

  def setup(redis)
    addr = [redis.fetch(:port), redis.fetch(:host)]
    addr[1] = (TCPSocket.gethostbyname(addr[1]).last)
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
