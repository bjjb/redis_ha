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
  end

  def connect(*conns)
    conns.each do |conn|
      @connections << RedisHA::Connection.new(conn, self)
      @connections.last.yield_connect
    end
  end

  def method_missing(*msg)
    req = RedisHA::Protocol.request(*msg)
    execute(req)
  end

private

  def execute(cmd)
    @connections.each do |c|
      c.rewind
      c << cmd
    end

    await

    @connections.map do |conn|
      res = RedisHA::Protocol.parse(conn.read_buffer)

      if res.is_a?(Exception)
        @connections.each(&:rewind)
        raise res
      else
        res
      end
    end
  end

  def select
    req = [[],[],[]]

    @connections.each do |c|
      req[0] << c if c.wait_read?
      req[1] << c if c.wait_write?
    end

    req << @read_timeout
    ready = IO.select(*req)

    unless ready
      req[0].each(&:execution_expired)
      req[1].each(&:execution_expired)
      return
    end

    ready[0].each(&:yield_read)
    ready[1].each(&:yield_write)
  end

  def await
    loop do
      begin
        await = false
        select

        @connections.each do |conn|
          next unless conn.up_or_retry?
          await = true unless conn.ready?
        end

        break unless await
      rescue Errno::EAGAIN, Errno::EINTR
        next
      end
    end
  end

end
