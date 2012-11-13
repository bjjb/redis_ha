require "rubygems"; require "redis"; load ::File.expand_path("../redis_ha_store.rb",__FILE__ )
require "pp"
require "benchmark"


def bm(label)
  t = Time.now.to_f
  yield
  d = (Time.now.to_f - t) * 1000
  puts "#{label}: #{d.to_i}ms"
end


RedisHAStore.default_retry_timeout = 0.5
RedisHAStore.default_read_timeout = 0.3
map = RedisHAStore::HashMap.new("fnordmap")
map.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6385}
)
bm "1000x HashMap.set w/ retries" do
  1000.times do |n|
    map.set(:fnord, :fu=>:bar, :fnord=>:bar)
  end
end

RedisHAStore.default_retry_timeout = 30
RedisHAStore.default_read_timeout = 0.3
map = RedisHAStore::HashMap.new("fnordmap")
map.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6385}
)
bm "1000x HashMap.set w/o retries" do
  1000.times do |n|
    map.set(:fnord, :fu=>:bar, :fnord=>:bar)
  end
end


bm "sequential connect" do
  map = RedisHAStore::HashMap.new("fnordmap")
  map.connect(:host => "localhost", :port => 6379)
  map.connect(:host => "localhost", :port => 6380)
  map.connect(:host => "localhost", :port => 6385)
  map.connect(:host => "localhost", :port => 6382)
  map.connect(:host => "localhost", :port => 6383)
end

bm "async connect" do
  map = RedisHAStore::HashMap.new("fnordmap")
  map.connect(
    {:host => "localhost", :port => 6379},
    {:host => "localhost", :port => 6380},
    {:host => "localhost", :port => 6385},
    {:host => "localhost", :port => 6382},
    {:host => "localhost", :port => 6383}
  )
end


