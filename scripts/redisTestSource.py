#!/usr/bin/env python3.11
"""Redis Key Type Auditor.

Connects to a Redis instance and reports the type, TTL, and size of every key.
Uses SCAN (non-blocking) instead of KEYS for production safety.

Usage:
    ./redisTestSource.py
    ./redisTestSource.py --host redis.example.com --port 6380 --db 2
    ./redisTestSource.py -u redis://:password@host:6379/0
"""

import argparse
import sys
import time

import redis


TYPE_LABELS = {
    b"string": "STRING",
    b"list": "LIST",
    b"set": "SET",
    b"zset": "ZSET",
    b"hash": "HASH",
    b"stream": "STREAM",
    b"none": "NONE",
}


def get_key_size(r: redis.Redis, key: bytes, key_type: bytes) -> int:
    """Return approximate memory size of a key in bytes."""
    try:
        return r.memory_usage(key) or 0
    except (redis.ResponseError, Exception):
        return 0


def scan_keys(r: redis.Redis, count=1000):
    """Generator that yields keys using SCAN (non-blocking)."""
    cursor = 0
    while True:
        cursor, keys = r.scan(cursor=cursor, count=count)
        for key in keys:
            yield key
        if cursor == 0:
            break


def audit(r: redis.Redis, match="*", count=1000):
    """Audit all keys matching the pattern and print summary."""
    stats = {}
    ttl_keys = 0
    no_ttl_keys = 0
    total_size = 0
    total_keys = 0

    start = time.monotonic()

    for key in scan_keys(r, count=count):
        key_type = r.type(key)
        type_label = TYPE_LABELS.get(key_type, key_type.decode(errors="replace"))

        stats[type_label] = stats.get(type_label, 0) + 1

        ttl = r.ttl(key)
        if ttl > 0:
            ttl_keys += 1
        else:
            no_ttl_keys += 1

        size = get_key_size(r, key, key_type)
        total_size += size
        total_keys += 1

    elapsed = time.monotonic() - start

    print(f"\n{'='*60}")
    print(f"Redis Key Audit Summary")
    print(f"Host: {r.connection_pool.connection_kwargs.get('host', 'unknown')}")
    print(f"DB:   {r.connection_pool.connection_kwargs.get('db', 0)}")
    print(f"{'='*60}")
    print(f"Total keys scanned: {total_keys:,}")
    print(f"Time elapsed:       {elapsed:.2f}s")
    print(f"Keys with TTL:      {ttl_keys:,}")
    print(f"Keys without TTL:   {no_ttl_keys:,}")
    print(f"Approx memory:      {total_size / 1024 / 1024:.2f} MB")
    print(f"{'='*60}")

    if stats:
        print(f"\n{'Type':<12} {'Count':>10} {'Percentage':>12}")
        print(f"{'-'*36}")
        for t in sorted(stats, key=stats.get, reverse=True):
            pct = (stats[t] / total_keys * 100) if total_keys else 0
            print(f"{t:<12} {stats[t]:>10,} {pct:>11.1f}%")

    print()


def main():
    parser = argparse.ArgumentParser(
        description="Audit Redis key types, TTLs, and memory usage."
    )
    parser.add_argument("-u", "--url", help="Redis URL (redis://[:pass@]host:port/db)")
    parser.add_argument("--host", default="localhost", help="Redis host (default: localhost)")
    parser.add_argument("--port", type=int, default=6379, help="Redis port (default: 6379)")
    parser.add_argument("--db", type=int, default=0, help="Redis DB number (default: 0)")
    parser.add_argument("--password", default=None, help="Redis password")
    parser.add_argument("--match", default="*", help="Key pattern to scan (default: *)")
    parser.add_argument(
        "--count", type=int, default=1000,
        help="SCAN count batch size (default: 1000)"
    )
    args = parser.parse_args()

    if args.url:
        r = redis.from_url(args.url, decode_responses=False)
    else:
        r = redis.Redis(
            host=args.host, port=args.port, db=args.db,
            password=args.password, decode_responses=False,
            socket_timeout=10, socket_connect_timeout=10,
        )

    # Test connection
    try:
        r.ping()
    except redis.ConnectionError as e:
        print(f"ERROR: Cannot connect to Redis: {e}", file=sys.stderr)
        sys.exit(1)

    audit(r, match=args.match, count=args.count)


if __name__ == "__main__":
    main()
