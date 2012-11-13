require "rubygems"; require "redis"; load ::File.expand_path("../redis_ha_store.rb",__FILE__ )
require "pp"
require "benchmark"


def bm(label)
  t = Time.now.to_f
  yield
  d = (Time.now.to_f - t) * 1000
  puts "#{label}: #{d.to_i}ms"
end

pool = RedisHAStore::ConnectionPool.new
pool.retry_timeout = 0.5
pool.read_timeout = 0.5
pool.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6385})

map = RedisHAStore::HashMap.new(pool, "fnordmap")

bm "1000x HashMap.set w/ retries" do
  1000.times do |n|
    map.set(:fu=>:bar, :fnord=>:bar)
  end
end

pool = RedisHAStore::ConnectionPool.new
pool.retry_timeout = 50
pool.read_timeout = 0.5
pool.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6385})

map = RedisHAStore::HashMap.new(pool, "fnordmap")

bm "1000x HashMap.set w/o retries" do
  1000.times do |n|
    map.set(:fu=>:bar, :fnord=>:bar)
  end
end


bm "sequential connect" do
  pool = RedisHAStore::ConnectionPool.new
  pool.connect(:host => "localhost", :port => 6379)
  pool.connect(:host => "localhost", :port => 6380)
  pool.connect(:host => "localhost", :port => 6385)
  pool.connect(:host => "localhost", :port => 6382)
  pool.connect(:host => "localhost", :port => 6383)
end

bm "async connect" do
  pool = RedisHAStore::ConnectionPool.new
  pool.connect(
    {:host => "localhost", :port => 6379},
    {:host => "localhost", :port => 6380},
    {:host => "localhost", :port => 6385},
    {:host => "localhost", :port => 6382},
    {:host => "localhost", :port => 6383}
  )
end
