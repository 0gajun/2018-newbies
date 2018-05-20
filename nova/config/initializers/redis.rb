redis_host = ENV['REDIS_HOST'] || '127.0.0.1'

Redis.current = Redis.new(host: redis_host, port: 6379, db: 0)
