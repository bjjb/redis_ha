require "rubygems"; require "redis"; load ::File.expand_path("../redis_ha_store.rb",__FILE__ )
require "pp"


map = RedisHAStore::HashMap.new("fnordmap")
map.add_redis(:host => "localhost", :port => 6379)
map.add_redis(:host => "localhost", :port => 6380)
map.add_redis(:host => "localhost", :port => 6381)
map.add_redis(:host => "localhost", :port => 6382)
map.add_redis(:host => "localhost", :port => 6383)

pp map.connections
