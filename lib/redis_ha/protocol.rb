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

  def self.parse(buf)
    case buf[0]
      when "-" then RuntimeError.new(buf[1..-3])
      when "+" then buf[1..-3]
      when ":" then buf[1..-3].to_i

      when "$"
         buf.sub(/.*\r\n/,"")[0...-3] if buf[1..2] != "-1"

      when "*"
        RuntimeError.new("multi bulk replies are not supported")

    end
  end

end
