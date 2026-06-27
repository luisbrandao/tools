#!/usr/bin/env bash
# Backward-compatible wrapper for nexus-clean.py generic subcommand
# Old usage:  python3 nexusRMgeneric.py -u https://repo.example.com -r my-repo -p "-73" --apply -y
# New usage: nexus-clean.py generic -u https://repo.example.com -r my-repo -p "-73" --apply -y

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3.11 "$SCRIPT_DIR/nexus-clean.py" generic "$@"
