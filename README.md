RedisHA
=======

A redis client that runs commands on multiple servers in parallel 
without blocking if one of them is down.

### Rationale

I used this to implement a highly available session store on top of
redis; it writes and reads to multiple servers and merges the responses 
after every read. 

This is negligibly slower than writing to a single server since RedisHA 
uses asynchronous I/O, but it is more resilient than a complex server-side
redis failover solution (sentinel, pacemaker, etcetera): you can `kill -9`
any server at any time and continue to read and write as long as at least
one server is healthy.

The gem includes three basic CRDTs (set, hashmap and counter).

[1] _DeCandia, Hastorun et al_ (2007). [Dynamo: Amazon’s Highly Available Key-value Store](http://www.read.seas.harvard.edu/~kohler/class/cs239-w08/decandia07dynamo.pd) (SOSP 2007)


Usage
-----

Create a RedisHA::ConnectionPool (`connect` does not block):

```ruby
pool = RedisHA::ConnectionPool.new
pool.connect(
  {:host => "localhost", :port => 6379},
  {:host => "localhost", :port => 6380},
  {:host => "localhost", :port => 6381}
)
```

Execute a command in parallel:

```ruby
>> pool.ping
=> ["PONG", "PONG", "PONG"]

>> pool.setnx "fnord", 1
=> [1, 1, 1]
```

Execute a command in parallel when server #2 is down:

```ruby
>> pool.ping
=> ["PONG", nil, "PONG"]

>> pool.setnx "fnord", 1
=> [1, nil, 1]
```


RedisHA::Counter (INCR/DECR/SET/GET)

```ruby
>> ctr = RedisHA::Counter.new(pool, "my-counter")

>> ctr.set 3
=> true

>> ctr.incr
=> true

>> ctr.get
=> 4
```

RedisHA::HashMap (SET/GET) 

```ruby
>> map = RedisHA::HashMap.new(pool, "my-hashmap")

>> map.set(:fnord => 1, :fubar => 2)
=> true

=> map.get
=> {:fnord=>1, :fubar=>2}
```

RedisHA::Set (ADD/REM/GET)

```ruby
>> set = RedisHA::Set.new(pool, "my-set")

>> set.add(:fnord, :bar)
=> true

>> set.rem(:bar)
=> true

>> set.get
=> [:fnord]
```



Installation
------------

    gem install redis_ha

or in your Gemfile:

    gem 'redis_ha', '>= 0.1'


Timeouts
--------

RedisHA implements two timeouts per connection: A `read_timeout` and a `retry_timeout`

When a server takes longer than read_timeout seconds to respond to a request it is 
considered down. Once a server is down it is excluded from subsequent requests for the 
given retry_timeout. 

That means if one server is down, one request will take at least read_timeout seconds
to complete every retry_timeout seconds.

The defaults are 500ms for read and 10s for the retry. If you are only using fast redis
operations you should set the read_timeout to 100ms or lower.

```ruby
pool = RedisHA::ConnectionPool.new
pool.retry_timeout = 10
pool.read_timeout = 0.1
```


Merge Strategies
----------------

The default merge strategy for `RedisHA::Set` favors addtions over deletions (a deleted
element might re-appear in a set if a server goes down and comes back up with an
old / inconsistent state, but a element can never be lost from a set as long as at least
one server is healthy)

The default merge strategy for `RedisHA::Counter` favor increments over decrements (a
counters value might be greater than the real value in some conditions but it can never
be less than the real value)

You can define your own merge strategy:

```ruby
>> ctr = RedisHA::Counter.new(pool, "my-counter")  

# select the smallest value when merging counter responses 
>> ctr.merge_strategy = lambda{ |values| vales.map(&:to_i).min }
```


License
-------

Copyright (c) 2011 Paul Asmuth

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to use, copy and modify copies of the Software, subject 
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
