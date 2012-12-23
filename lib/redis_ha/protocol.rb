class RedisHA::Protocol

  def self.request(*args)
    args.inject("*#{args.size}\r\n") do |s, arg|
      s << "$#{arg.to_s.length}\r\n#{arg}\r\n"
    end
  end

  def self.peek?(buf)
    if ["+", ":", "-"].include?(buf[0])
      !!buf.index("\r\n")

    elsif ["$", "*"].include?(buf[0])
      offset = buf.index("\r\n").to_i
      return false if offset == 0
      length = buf[1..offset].to_i
      return true if length == -1
      offset += 2

      if buf[0] == "*"
        multi = length
        length.times do |ind|
          if buf[offset+1..offset+2] == "-1"
            offset += 5
          elsif /^\$(?<len>[0-9]+)\r\n/ =~ buf[offset..-1]
            length = len.to_i
            offset += len.length + 3
            offset += length + 2 if ind < multi - 1
          else
            return false
          end
        end
      end

      buf.size >= (length + offset + 2)
    end
  end

  def self.parse(buf)
    case buf[0]
      when "-", "+", ":" then
        len = buf.index("\r\n")
        ret = buf[0..len-1]
        buf.replace(buf[len+2..-1])

        case ret[0]
          when "+" then ret[1..-1]
          when ":" then ret[1..-1].to_i
          when "-" then RuntimeError.new(ret[1..-1])
        end

      when "$"
        if buf[1..2] == "-1"
          buf.replace(buf[5..-1] || "")
          nil
        else
          len = buf.match(/^\$([-0-9]+)\r\n/)[1]
          ret = buf[len.length+3..len.length+len.to_i+2]
          buf.replace(buf[len.to_i+len.length+5..-1] || "")
          ret
        end

      when "*"
        cnt = buf.match(/^\*([0-9]+)\r\n/)[1]
        buf = buf[cnt.length+3..-1]
        cnt.to_i.times.map { parse(buf) }

    end
  end

end
