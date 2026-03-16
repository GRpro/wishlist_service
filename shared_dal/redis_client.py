import os
import redis
import json

class RedisCache:
    def __init__(self):
        host = os.getenv("REDIS_HOST", "localhost")
        port = int(os.getenv("REDIS_PORT", 6379))
        self.client = redis.Redis(host=host, port=port, decode_responses=True)

    def get_json(self, key):
        data = self.client.get(key)
        return json.loads(data) if data else None

    def set_json(self, key, value, ttl_seconds=3600):
        self.client.set(key, json.dumps(value), ex=ttl_seconds)

    def invalidate(self, key):
        self.client.delete(key)