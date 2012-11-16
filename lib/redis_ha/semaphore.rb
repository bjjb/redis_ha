class RedisHA::Semaphore

  POLL_INTERVAL = 0.001

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
    sleep(POLL_INTERVAL) while @n != 0
  end

end
