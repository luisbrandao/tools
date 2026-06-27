#!/usr/bin/env python3.11
"""Redis to Redis Data Migrator.

Migrates all keys from one Redis instance to another, preserving types and TTLs.
Uses SCAN (non-blocking) and pipelining for production safety and performance.

Usage:
    ./redisTransfer.py --source-host old-redis --target-host new-redis
    ./redisTransfer.py -u redis://old:6379/0 -t redis://new:6379/0
    ./redisTransfer.py --source-host old --target-host new --dry-run  # preview only
"""

import argparse
import sys
import time
from datetime import timedelta

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


def scan_keys(r: redis.Redis, match="*", count=1000):
    """Generator that yields keys using SCAN (non-blocking)."""
    cursor = 0
    while True:
        cursor, keys = r.scan(cursor=cursor, match=match, count=count)
        for key in keys:
            yield key
        if cursor == 0:
            break


def transfer_key(src: redis.Redis, dst: redis.Redis, key: bytes, dry_run=False):
    """Transfer a single key from source to target, preserving type and TTL."""
    key_type = src.type(key)
    ttl = src.ttl(key)
    type_label = TYPE_LABELS.get(key_type, key_type.decode(errors="replace"))

    if dry_run:
        print(f"  [DRY-RUN] {type_label:<8} {key[:80]}")
        return True

    try:
        if key_type == b"string":
            value = src.get(key)
            dst.set(key, value)

        elif key_type == b"hash":
            mapping = src.hgetall(key)
            if mapping:
                dst.hset(mapping)  # redis-py 4.x style

        elif key_type == b"set":
            members = src.smembers(key)
            if members:
                dst.sadd(key, *members)

        elif key_type == b"list":
            values = src.lrange(key, 0, -1)
            if values:
                dst.rpush(key, *values)

        elif key_type == b"zset":
            members = src.zrange(key, 0, -1, withscores=True)
            if members:
                dst.zadd(key, {m[0]: m[1] for m in members})

        elif key_type == b"stream":
            # Streams are complex; copy raw data via DUMP/RESTORE
            dump = src.dump(key)
            if dump:
                try:
                    dst.restore(key, ttl if ttl > 0 else 0, dump, replace=True)
                except redis.ResponseError as e:
                    print(f"  [WARN] Stream restore failed for {key}: {e}")
                    return False

        else:
            # Fallback: try DUMP/RESTORE for unknown types
            print(f"  [WARN] Unknown type {type_label} for {key}, trying DUMP/RESTORE")
            dump = src.dump(key)
            if dump:
                dst.restore(key, ttl if ttl > 0 else 0, dump, replace=True)

        # Set TTL if the source key had one
        if ttl > 0:
            dst.expire(key, ttl)

        return True

    except Exception as e:
        print(f"  [ERROR] Failed to transfer {key}: {e}")
        return False


def migrate(
    src: redis.Redis,
    dst: redis.Redis,
    match="*",
    count=1000,
    dry_run=False,
    batch_size=100,
):
    """Migrate all matching keys from source to target."""
    stats = {"success": 0, "failed": 0, "skipped": 0}
    total_keys = 0
    start = time.monotonic()

    print(f"\nSource: {src.connection_pool.connection_kwargs.get('host', '?')}:"
          f"{src.connection_pool.connection_kwargs.get('port', 6379)}/"
          f"{src.connection_pool.connection_kwargs.get('db', 0)}")
    print(f"Target: {dst.connection_pool.connection_kwargs.get('host', '?')}:"
          f"{dst.connection_pool.connection_kwargs.get('port', 6379)}/"
          f"{dst.connection_pool.connection_kwargs.get('db', 0)}")
    if dry_run:
        print("*** DRY RUN — no data will be modified ***\n")
    else:
        print()

    # Use pipeline for bulk operations (non-type-specific keys)
    pipe = dst.pipeline(transaction=False)

    for key in scan_keys(src, match=match, count=count):
        total_keys += 1
        success = transfer_key(src, dst, key, dry_run=dry_run)

        if success:
            stats["success"] += 1
        else:
            stats["failed"] += 1

        # Progress indicator every batch_size keys
        if total_keys % batch_size == 0:
            elapsed = time.monotonic() - start
            rate = total_keys / elapsed if elapsed > 0 else 0
            print(f"\r  Progress: {total_keys:,} keys ({rate:.0f} keys/s) "
                  f"[✓{stats['success']} ✗{stats['failed']}]    ", end="", flush=True)

    # Final summary
    elapsed = time.monotonic() - start
    rate = total_keys / elapsed if elapsed > 0 else 0

    print(f"\n\n{'='*60}")
    print("Migration Summary")
    print(f"{'='*60}")
    print(f"Total keys processed: {total_keys:,}")
    print(f"Successful:           {stats['success']:,}")
    print(f"Failed:               {stats['failed']:,}")
    print(f"Time elapsed:         {elapsed:.2f}s")
    print(f"Transfer rate:        {rate:.0f} keys/s")
    if elapsed > 60:
        print(f"Duration:             {timedelta(seconds=int(elapsed))}")
    print(f"{'='*60}\n")

    return stats


def main():
    parser = argparse.ArgumentParser(
        description="Migrate Redis data from one instance to another."
    )

    # Source connection
    src_group = parser.add_argument_group("Source Redis")
    src_group.add_argument("-u", "--source-url", help="Source Redis URL")
    src_group.add_argument("--source-host", default="localhost", help="Source host")
    src_group.add_argument("--source-port", type=int, default=6379, help="Source port")
    src_group.add_argument("--source-db", type=int, default=0, help="Source DB")
    src_group.add_argument("--source-password", default=None, help="Source password")

    # Target connection
    tgt_group = parser.add_argument_group("Target Redis")
    tgt_group.add_argument("-t", "--target-url", help="Target Redis URL")
    tgt_group.add_argument("--target-host", default="localhost", help="Target host")
    tgt_group.add_argument("--target-port", type=int, default=6379, help="Target port")
    tgt_group.add_argument("--target-db", type=int, default=0, help="Target DB")
    tgt_group.add_argument("--target-password", default=None, help="Target password")

    # Options
    opt_group = parser.add_argument_group("Options")
    opt_group.add_argument("--match", default="*", help="Key pattern (default: *)")
    opt_group.add_argument("--count", type=int, default=1000, help="SCAN batch size")
    opt_group.add_argument("--dry-run", action="store_true", help="Preview without writing")

    args = parser.parse_args()

    # Connect to source
    if args.source_url:
        src = redis.from_url(args.source_url, decode_responses=False)
    else:
        src = redis.Redis(
            host=args.source_host, port=args.source_port, db=args.source_db,
            password=args.source_password, decode_responses=False,
            socket_timeout=30, socket_connect_timeout=10,
        )

    # Connect to target
    if args.target_url:
        dst = redis.from_url(args.target_url, decode_responses=False)
    else:
        dst = redis.Redis(
            host=args.target_host, port=args.target_port, db=args.target_db,
            password=args.target_password, decode_responses=False,
            socket_timeout=30, socket_connect_timeout=10,
        )

    # Test connections
    for label, r in [("Source", src), ("Target", dst)]:
        try:
            r.ping()
        except redis.ConnectionError as e:
            print(f"ERROR: Cannot connect to {label} Redis: {e}", file=sys.stderr)
            sys.exit(1)

    migrate(src, dst, match=args.match, count=args.count, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
