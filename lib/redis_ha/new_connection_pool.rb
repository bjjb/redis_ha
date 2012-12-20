class RedisHA::NewConnectionPool

  class ExecutionFinished < StandardError; end

  class Connection < Socket
    attr_accessor :addr, :read_buffer, :write_buffer

    def initialize(opts)
      super(AF_INET, SOCK_STREAM, 0)
      @write_buffer = ""
      @read_buffer = ""
      @__addr = Socket.pack_sockaddr_in(
        opts.fetch(:port), opts.fetch(:host))
    end

    def connect
      connect_nonblock(@__addr)
    rescue Errno::EINPROGRESS
      nil
    rescue Errno::ECONNREFUSED
      STDOUT.puts "conn refused"
      @ready = true
    end

    def yield_read
      loop do
        @read_buffer << read_nonblock(1)[0]
      end
    rescue Errno::EAGAIN
      check || raise(Errno::EAGAIN)
    rescue Errno::ENOTCONN
      connect
    rescue Errno::ECONNREFUSED
      STDOUT.puts "conn refused"
      @ready = true
    end

    def yield_write
      len = write_nonblock(@write_buffer)
      @write_buffer = @write_buffer[len..-1] || ""
    rescue Errno::EPIPE
      connect
    rescue Errno::ECONNREFUSED
      STDOUT.puts "conn refused"
      @ready = true
    end

    def <<(buf)
      @ready = false
      @write_buffer << buf
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
      STDOUT.puts "execution expired"
      @ready = true
    end

    def ready?
      @ready == true
    end

    def check
      STDOUT.puts "check"
      @ready = @read_buffer.size > 3
    end

  end

  def initialize
    @conns = []
  end

  def add_redis(opts)
    #sock.connect(addr)

    @conns << RedisHA::NewConnectionPool::Connection.new(opts)
    true
  end

  def execute(cmd)
    @conns.each do |c|
      c << "*1\r\n$4\r\nPING\r\n"
    end

    await

    @conns.map do |conn|
      conn.read_buffer
    end
  end

private

  def select
    puts "-"*30
    puts "write: " << @conns.map(&:write_buffer).inspect
    puts "read: " << @conns.map(&:read_buffer).inspect

    req = [[],[],[]]

    @conns.each do |c|
      req[0] << c if c.wait_read?
      req[1] << c if c.wait_write?
    end

    puts req.inspect

    req << 20
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

        @conns.each do |conn|
          await = true unless conn.ready?
        end

        break unless await
      rescue Errno::EAGAIN, Errno::EINTR
        next
      end
    end
  end

end
