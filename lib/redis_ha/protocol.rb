class RedisHA::Protocol


  def self.request(*args)
    args.inject("*#{args.size}\r\n") do |s, arg|
      s << "$#{arg.size}\r\n#{arg}\r\n"
    end
  end


end
