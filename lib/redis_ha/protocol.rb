class RedisHA::Protocol


  def self.request(*args)
    args.inject("*#{args.size}\r\n") do |s, arg|
      s << "$#{arg.size}\r\n#{arg}\r\n"
    end
  end

  def self.peek?(buf)
    if ["+", ":", "-"].include?(buf[0])
      buf[-2..-1] == "\r\n"
    elsif buf[0] == "$"
      offset = buf.index("\r\n").to_i
      return false if offset == 0
      length = buf[1..offset].to_i
      return true if length == -1
      buf.size >= (length + offset + 2)
    elsif buf[0] == "*"
      true
    end
  end

end
