require "rubygems"
 require "redis"
 require "pp"
 require "ripl"

def bm(label)
  t = Time.now.to_f
  yield
  d = (Time.now.to_f - t) * 1000
  puts "#{label}: #{d.round(2)}ms"
end

$: << ::File.expand_path("..", __FILE__)
require "redis_ha"

pool = RedisHA::ConnectionPool.new
pool.retry_timeout = 0.5
pool.read_timeout = 10.1
pool.connect(
  {:host => "localhost", :port => 6379})

#map = RedisHA::HashMap.new(pool, "fnordmap")
#set = RedisHA::Set.new(pool, "fnordset")
ctr = RedisHA::Counter.new(pool, "fnordctr")

Ripl.start :binding => binding
exit

#puts pool.ping.inspect

[100, 1000, 10000].each do |b|
  bm "#{b}x ping" do
    b.times do |n|
      pool.ping
    end
  end
end

while sleep 1
  bm "1000x ping" do
    1000.times do |n|
      pool.ping
    end
  end
end

bm "1000x HashMap.set w/ retries" do
  1000.times do |n|
    map.set(:fu=>:bar, :fnord=>:bar)
  end
end

pool = RedisHA::ConnectionPool.new
pool.retry_timeout = 50
pool.read_timeout = 0.5
pool.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6385})

map = RedisHA::HashMap.new(pool, "fnordmap")

bm "1000x HashMap.set w/o retries" do
  1000.times do |n|
    map.set(:fu=>:bar, :fnord=>:bar)
  end
end


bm "sequential connect" do
  pool = RedisHA::ConnectionPool.new
  pool.connect(:host => "localhost", :port => 6379)
  pool.connect(:host => "localhost", :port => 6380)
  pool.connect(:host => "localhost", :port => 6385)
  pool.connect(:host => "localhost", :port => 6382)
  pool.connect(:host => "localhost", :port => 6383)
end

bm "async connect" do
  pool = RedisHA::ConnectionPool.new
  pool.connect(
    {:host => "localhost", :port => 6379},
    {:host => "localhost", :port => 6380},
    {:host => "localhost", :port => 6385},
    {:host => "localhost", :port => 6382},
    {:host => "localhost", :port => 6383}
  )
end
