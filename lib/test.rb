require "rubygems"; require "redis"; load ::File.expand_path("../redis_ha_store.rb",__FILE__ )
require "pp"
require "benchmark"


def bm(label)
  t = Time.now.to_f
  yield
  d = (Time.now.to_f - t) * 1000
  puts "#{label}: #{d.to_i}ms"
end

bm "sequential connect" do
  map = RedisHAStore::HashMap.new("fnordmap")
  map.connect(:host => "localhost", :port => 6379)
  map.connect(:host => "localhost", :port => 6380)
  map.connect(:host => "localhost", :port => 6385)
  map.connect(:host => "localhost", :port => 6382)
  map.connect(:host => "localhost", :port => 6383)
  pp map.connections
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
  pp map.connections
end
