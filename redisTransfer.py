import redis
source = redis.Redis(host="641c676bca25.agrotis.io", port=6379, db=0)
target = redis.Redis(host="redis-ha-haproxy", port=6379, db=0)

keys = source.keys()


for key, tipo, ttl in zip(keys, map(source.type, keys), map(source.ttl, keys)):
  if tipo == b'string':
    value = source.get(key)
    target.set(key,value)
    if not ttl == -1:
      target.expire(key, ttl)

  elif tipo == b'hash':
    value = source.hgetall(key)
    target.hmset(key,value)
    if not ttl == -1:
      target.expire(key, ttl)

  elif tipo == b'set':
    for value in source.smembers(key):
      target.sadd(key,value)
    if not ttl == -1:
      target.expire(key, ttl)
  else:
    print("Sabe deus que merda eh essa:", tipo)
