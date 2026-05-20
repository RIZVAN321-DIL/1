from datetime import datetime, timedelta

class MemoryCache:
    def __init__(self):
        self._store = {}
        self._expire = {}
    def set(self, key: str, value, ttl_seconds: int = 300):
        self._store[key] = value
        self._expire[key] = datetime.now() + timedelta(seconds=ttl_seconds)
    def get(self, key: str):
        if key in self._expire and datetime.now() > self._expire[key]:
            self.delete(key)
            return None
        return self._store.get(key)
    def delete(self, key: str):
        self._store.pop(key, None)
        self._expire.pop(key, None)

cache = MemoryCache()
