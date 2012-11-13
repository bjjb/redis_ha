class RedisHA::HashMap < RedisHA::Base

  # this lambda defines how the individual response hashes are merged
  # the default is to merge in reverse-chronological order
  DEFAULT_MERGE_STRATEGY = ->(v) { v
    .sort{ |a,b| a[:_time] <=> b[:_time] }
    .inject({}){ |t,c| t.merge!(c) } }


  def set(data = {})
    data.merge!(:_time => Time.now.to_i)
    pool.set(@key, Marshal.dump(data))
    true
  end

  def get
    versions = pool.get(@key).map do |v|
      next if v.nil? || v == ""
      puts v.inspect
      Marshal.load(v) rescue nil
    end.compact
    merge_strategy[versions].tap do |merged|
      merged.delete(:_time)
    end
  end

  def merge_strategy
    @merge_strategy || DEFAULT_MERGE_STRATEGY
  end

end
