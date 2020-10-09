import redis
source = redis.Redis(host="641c676bca25.agrotis.io", port=6379, db=0)

keys = source.keys()

string = 0
hash = 0
set = 0


for key in keys:
  tipo = source.type(key)
  ttl = source.ttl(key)
  if tipo == b'string':
    print ("eh string ", ttl)
    string = string + 1
  elif tipo == b'hash':
    print ("eh hash ", ttl)
    hash = hash + 1
  elif tipo == b'set':
    print ("eh set ", ttl)
    set = set + 1
  else:
    print("Sabe deus que merda eh essa", tipo)


print ("Strings: ", string)
print ("Hashes:  ", hash)
print ("Sets:    ", set)
