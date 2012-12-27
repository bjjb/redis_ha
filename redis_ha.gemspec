# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "redis_ha"
  s.version     = "0.1.3"
  s.date        = Date.today.to_s
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Paul Asmuth"]
  s.email       = ["paul@paulasmuth.com"]
  s.homepage    = "http://github.com/paulasmuth/redis_ha"
  s.summary     = %q{basic CRDTs and a HA connection pool for redis}
  s.description = %q{Three basic CRDTs (set, hashmap and counter) for redis. Also includes a ConnectionPool that allows you to run concurrent redis commands on multiple connections w/o using eventmachine/em-hiredis.}
  s.licenses    = ["MIT"]

  s.add_dependency "redis", ">= 2.2.2"

  s.files         = `git ls-files`.split("\n") - [".gitignore", ".rspec", ".travis.yml"]
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ["lib"]
end
