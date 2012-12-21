RedisHA
=======

A redis client that runs commands on multiple servers in parallel 
without blocking if one of them is down.

I used this to implement a highly available session store on top of
redis; it writes and reads the data to multiple instances and merges 
the responses after every read. This approach is negligibly slower 
than writing to a single server since RedisHA uses asynchronous I/O 
and is much more robust than complex server-side redis failover solutions
(sentinel, pacemaker, etcetera).

The gem includes three basic CRDTs (set, hashmap and counter).

[1] _DeCandia, Hastorun et al_ (2007). [Dynamo: Amazon’s Highly Available Key-value Store](http://www.read.seas.harvard.edu/~kohler/class/cs239-w08/decandia07dynamo.pd) (SOSP 2007)


Usage
-----

Create a RedisHA::ConnectionPool (connect does not block):

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
=> [1,1,1]
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

Timeouts
--------

here be dragons


Caveats
--------

-> delete / decrement is not safe




Installation
------------

    gem install redis_ha

or in your Gemfile:

    gem 'redis_ha', '~> 0.3'


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
