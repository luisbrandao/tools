#!/usr/bin/env python3
"""
Parse dnsmasq logs and track domain query counts in SQLite
"""

import sqlite3
import re
import os
import sys
from pathlib import Path
from datetime import datetime


# Configuration
LOG_FILE = "/var/log/dnsmasq.log"
DB_FILE = "/var/lib/dnsmasq_stats/queries.db"
STATE_FILE = "/var/lib/dnsmasq_stats/last_position"
PROM_FILE = "/var/lib/node_exporter/textfile_collector/dnsmasq_domains.prom"

# Regex to match query lines
# Example: Oct  4 00:23:11 dnsmasq[393822]: query[A] accounts.google.com from 192.168.0.78
QUERY_PATTERN = re.compile(r'query\[(A|AAAA)\]\s+(\S+)\s+from')


def init_db():
    """Initialize SQLite database"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS domain_queries (
            domain TEXT PRIMARY KEY,
            query_count INTEGER DEFAULT 0,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    return conn


def get_last_position():
    """Get the last read position in the log file"""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return int(f.read().strip())
    return 0


def save_last_position(position):
    """Save the current read position"""
    with open(STATE_FILE, 'w') as f:
        f.write(str(position))


def parse_new_logs(last_position):
    """Parse log file from last position and count queries"""
    domain_counts = {}
    
    try:
        with open(LOG_FILE, 'r') as f:
            # Seek to last position
            f.seek(last_position)
            
            for line in f:
                match = QUERY_PATTERN.search(line)
                if match:
                    query_type = match.group(1)  # A or AAAA
                    domain = match.group(2)
                    
                    # Increment count
                    domain_counts[domain] = domain_counts.get(domain, 0) + 1
            
            # Save current position
            current_position = f.tell()
            
    except FileNotFoundError:
        print(f"Log file not found: {LOG_FILE}", file=sys.stderr)
        return domain_counts, last_position
    
    return domain_counts, current_position


def update_database(conn, domain_counts):
    """Update database with new query counts"""
    cursor = conn.cursor()
    
    for domain, count in domain_counts.items():
        cursor.execute('''
            INSERT INTO domain_queries (domain, query_count, last_updated)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(domain) DO UPDATE SET
                query_count = query_count + ?,
                last_updated = CURRENT_TIMESTAMP
        ''', (domain, count, count))
    
    conn.commit()


def export_to_prometheus(conn):
    """Export current stats to Prometheus textfile format"""
    cursor = conn.cursor()
    cursor.execute('SELECT domain, query_count FROM domain_queries ORDER BY query_count DESC')
    
    with open(PROM_FILE + '.tmp', 'w') as f:
        f.write('# HELP dnsmasq_domain_queries_total Total DNS queries per domain\n')
        f.write('# TYPE dnsmasq_domain_queries_total counter\n')
        
        for domain, count in cursor.fetchall():
            # Sanitize domain name for Prometheus
            safe_domain = re.sub(r'[^a-zA-Z0-9._-]', '_', domain)
            f.write(f'dnsmasq_domain_queries_total{{domain="{safe_domain}"}} {count}\n')
        
        f.write('\n# HELP dnsmasq_stats_last_update Last update timestamp\n')
        f.write('# TYPE dnsmasq_stats_last_update gauge\n')
        f.write(f'dnsmasq_stats_last_update {int(os.path.getmtime(DB_FILE))}\n')
    
    # Atomic move
    os.rename(PROM_FILE + '.tmp', PROM_FILE)


def main():
    """Main execution"""
    # Initialize database
    conn = init_db()
    
    # Get last position
    last_position = get_last_position()
    
    # Parse new log entries
    domain_counts, new_position = parse_new_logs(last_position)
    
    # Update database
    if domain_counts:
        update_database(conn, domain_counts)
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{timestamp}] Processed {len(domain_counts)} unique domains, {sum(domain_counts.values())} total queries")
    else:
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"[{timestamp}] No new queries to process")
    
    # Save new position
    save_last_position(new_position)
    
    # Export to Prometheus
    export_to_prometheus(conn)
    
    # Cleanup
    conn.close()


if __name__ == '__main__':
    main()
