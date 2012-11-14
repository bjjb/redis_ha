RedisHA
=======

Three basic CRDTs (set, hashmap and counter) for redis. Also includes
a ConnectionPool that allows you to run concurrent redis commands on
multiple connections w/o using eventmachine/em-hiredis.

Usage
-----

Create a RedisHA::ConnectionPool

    here be dragons


ADD/REM/GET on a RedisHA::Set

    here be dragons


INCR/DECR/SET/GET on a RedisHA::Counter

    here be dragons


SET/GET on a RedisHA::HashMap

    here be dragons




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
