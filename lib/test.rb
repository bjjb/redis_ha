require "rubygems"
 require "redis"
 require "pp"
 require "ripl"

def bm(label)
  t = Time.now.to_f
  yield
  d = (Time.now.to_f - t) * 1000
  puts "#{label}: #{d.to_i}ms"
end

$: << ::File.expand_path("..", __FILE__)
require "redis_ha"

pool = RedisHA::ConnectionPool.new
pool.retry_timeout = 0.5
pool.read_timeout = 0.1
pool.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6381})

map = RedisHA::HashMap.new(pool, "fnordmap")
set = RedisHA::Set.new(pool, "fnordset")
ctr = RedisHA::Counter.new(pool, "fnordctr")

load "./redis_ha/new_connection_pool.rb"
p=RedisHA::NewConnectionPool.new
p.add_redis(:host => "127.0.0.1", :port => (ENV["PORT"]||6379).to_i)
p.add_redis(:host => "127.0.0.1", :port => (6380).to_i)
x = p.execute(:ping)
puts x.inspect

#Ripl.start :binding => binding
exit

bm "1000x ping" do
  1000.times do |n|
    pool.ping
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
