#!/usr/bin/env python3.11
"""
nexus-clean.py  —  Nexus Repository Manager artifact cleanup tool

Searches and optionally deletes assets from Nexus Repository Manager repositories.
Supports Docker, Maven, Static, and generic path-based searches with pagination,
sorting, dry-run preview, and "keep last N" retention policies.

Requires:
    pip install requests tqdm

Credential Resolution (in order of precedence):
    1. CLI arguments (--url, --user, --pass)
    2. Environment variables (NEXUS_URL, NEXUS_USER, NEXUS_PASS)
    3. .env file in current directory or ~/.nexus-clean.env
    4. Interactive prompt (for username/password only)

Env File Format (.env or .nexus-clean.env):
    # Lines starting with # are comments
    NEXUS_URL=https://your-nexus-server.example.com
    NEXUS_USER=your_username
    NEXUS_PASS=your_password

The .env file is excluded from Git (see .gitignore).

Examples:
    # Docker — list images matching patterns
    nexus-clean.py docker local-registry acc-backend "blue-*" "purple-*"

    # Docker — delete, keeping last 5 versions
    nexus-clean.py docker local-registry acc-backend "blue-*" --keep 5 --apply -y

    # Maven — delete artifacts by group + version patterns
    nexus-clean.py maven releases br.com.example.acc "green-*" "purple.*" --apply

    # Static — delete frontend builds, keeping last 3
    nexus-clean.py static static-repo core "v1.2-*" --keep 3 --apply

    # Generic — delete by path substring
    nexus-clean.py generic rhel-10-techsytes -p "-73" --apply -y

Exit Codes:
    0   Success (or dry-run preview)
    1   Error (network, auth, API failure)
"""

import argparse
import getpass
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

try:
    from tqdm import tqdm
except ImportError:
    tqdm = None  # graceful fallback

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SEARCH_V1 = "/service/rest/v1/search"
SEARCH_ASSETS_V1 = "/service/rest/v1/search/assets"

ENV_FILE_KEYS = {"NEXUS_URL", "NEXUS_USER", "NEXUS_PASS"}
ENV_FILE_LOCATIONS = [".env", ".nexus-clean.env", "~/.nexus-clean.env"]


def load_env_file(env_vars: Dict[str, Optional[str]]) -> Dict[str, str]:
    """Load credentials from .env file (KEY=VALUE format).

    Checks multiple locations in order:
      1. Current directory: .env
      2. Current directory: .nexus-clean.env
      3. Home directory: ~/.nexus-clean.env

    Only loads a key if it's NOT already set (precedence: env vars > .env file).
    Returns dict with keys that were loaded from file.
    """
    loaded = {}
    for env_path in ENV_FILE_LOCATIONS:
        path = Path(env_path).expanduser()
        if not path.is_file():
            continue
        try:
            with open(path, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" not in line:
                        continue
                    key, _, value = line.partition("=")
                    key = key.strip()
                    value = value.strip().strip("'\"")
                    if key in ENV_FILE_KEYS and env_vars.get(key) is None:
                        env_vars[key] = value
                        loaded[key] = value
                        if len(loaded) == len(ENV_FILE_KEYS):
                            break
        except (OSError, PermissionError):
            pass  # skip unreadable files silently
        if len(loaded) == len(ENV_FILE_KEYS):
            break

    return loaded


# Resolve NEXUS_URL: CLI arg → env var → .env file → default
_env_cache: Dict[str, Optional[str]] = {
    "NEXUS_URL": os.getenv("NEXUS_URL"),
    "NEXUS_USER": os.getenv("NEXUS_USER"),
    "NEXUS_PASS": os.getenv("NEXUS_PASS"),
}
load_env_file(_env_cache)
DEFAULT_URL = _env_cache.get("NEXUS_URL") or "https://nexus.example.com"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def ask_yes_no(question: str, default: bool = False) -> bool:
    """Prompt y/N with configurable default."""
    if default:
        return True
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    prompt = " [Y/n] " if default else " [y/N] "
    while True:
        sys.stdout.write(f"{question}{prompt}")
        choice = input().strip().lower()
        if choice == "":
            return default
        if choice in valid:
            return valid[choice]
        sys.stdout.write("Please respond with 'yes'/'no' (or 'y'/'n').\n")


def get_credentials(user: Optional[str], password: Optional[str]) -> tuple:
    """Resolve credentials from args → env vars → .env file → interactive prompt."""
    if not user:
        user = _env_cache.get("NEXUS_USER") or os.getenv("NEXUS_USER")
    if not password:
        password = _env_cache.get("NEXUS_PASS") or os.getenv("NEXUS_PASS")
    if not user:
        user = input("Nexus user: ")
    if not password:
        password = getpass.getpass("Nexus password: ")
    return user, password


def paginate_search(session: requests.Session, base_url: str, params: Dict[str, Any],
                    debug: bool = False) -> List[Dict[str, Any]]:
    """Fetch all pages from Nexus /search endpoint using continuationToken."""
    items: List[Dict[str, Any]] = []
    token = None
    while True:
        req_params = dict(params)
        if token:
            req_params["continuationToken"] = token
        r = session.get(f"{base_url}{SEARCH_V1}", params=req_params, timeout=30)
        if debug:
            print(f"DEBUG search: {r.url} -> {r.status_code}", file=sys.stderr)
        r.raise_for_status()
        data = r.json()
        items.extend(data.get("items", []))
        token = data.get("continuationToken")
        if not token:
            break
    return items


def paginate_search_assets(session: requests.Session, base_url: str,
                           params: Dict[str, Any], debug: bool = False) -> List[Dict[str, Any]]:
    """Fetch all pages from Nexus /search/assets endpoint."""
    items: List[Dict[str, Any]] = []
    token = None
    while True:
        req_params = dict(params)
        if token:
            req_params["continuationToken"] = token
        r = session.get(f"{base_url}{SEARCH_ASSETS_V1}", params=req_params, timeout=30)
        if debug:
            print(f"DEBUG search: {r.url} -> {r.status_code}", file=sys.stderr)
        r.raise_for_status()
        data = r.json()
        items.extend(data.get("items", []))
        token = data.get("continuationToken")
        if not token:
            break
    return items


def delete_with_progress(session: requests.Session, urls: List[str],
                         label: str = "deleting") -> int:
    """DELETE a list of URLs with progress bar. Returns count of failures."""
    total = len(urls)
    if not total:
        return 0
    progress = tqdm(total=total, unit="asset", desc=label) if tqdm else None
    failures = 0
    for idx, url in enumerate(urls, 1):
        resp = session.delete(url, timeout=60)
        ok = resp.ok
        if not ok:
            failures += 1
        msg = f"{'OK' if ok else 'FAIL'} {idx:>4}/{total}  {url}"
        if progress:
            progress.set_description(msg[:120])
            progress.update(1)
        else:
            print(msg)
    if progress:
        progress.close()
    return failures


def extract_version_number(version: str) -> int:
    """Extract numeric portion from version strings like 'blue-37' or 'v1.2.3'."""
    nums = re.findall(r'\d+', version)
    return int(nums[0]) if nums else 0


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------
def cmd_docker(args) -> int:
    """Search/delete Docker images by component name + version tag patterns.

    Uses the Nexus /search endpoint with format=docker, name=<component>,
    version=<tag_pattern>. Deletes via manifests/sha256:<checksum>.
    """
    base = args.url.rstrip("/")
    repo = args.repo
    name = args.name
    version_patterns = args.versions

    session = requests.Session()
    if args.debug:
        print(f"Searching Docker images in {repo} for {name}:{version_patterns}", file=sys.stderr)

    # Collect all matching items across all version patterns
    all_items: List[Dict[str, Any]] = []
    for pattern in version_patterns:
        params = {
            "format": "docker",
            "name": name,
        }
        # Omit version param when wildcard "*" — Nexus returns all versions
        if pattern != "*":
            params["version"] = pattern
        if repo:
            params["repository_name"] = repo
        items = paginate_search(session, base, params, debug=args.debug)
        for item in items:
            # Parse version number for sorting
            ver = item.get("version", "")
            item["_sort_key"] = extract_version_number(ver)
            all_items.append(item)

    # Deduplicate by SHA256 (same image may match multiple patterns)
    seen_shas = set()
    unique_items: List[Dict[str, Any]] = []
    for item in all_items:
        sha = item.get("assets", [{}])[0].get("checksum", {}).get("sha256", "")
        if sha and sha not in seen_shas:
            seen_shas.add(sha)
            unique_items.append(item)

    # Sort by extracted version number
    unique_items.sort(key=lambda x: x["_sort_key"], reverse=args.reverse)

    # Apply --keep N (retain last N versions)
    kept: List[Dict[str, Any]] = []
    if args.keep is not None and len(unique_items) > args.keep:
        to_delete = unique_items[:-args.keep]
        kept = unique_items[-args.keep:]
        print(f"Keeping last {args.keep} version(s):")
        for k in kept:
            print(f"  [keep] {k['name']}:{k['version']}")
    elif args.keep is not None:
        # Total images <= keep count — nothing to delete
        kept = unique_items
        to_delete = []
    else:
        to_delete = unique_items

    # Display results
    if not to_delete:
        print("No Docker images matched (or all retained by --keep).")
        return 0

    print(f"\nFound {len(to_delete)} Docker image(s) to delete:")
    for item in to_delete:
        ver = item.get("version", "?")
        sha = item.get("assets", [{}])[0].get("checksum", {}).get("sha256", "?")[:12]
        print(f"  {item['name']}:{ver}  (sha256:{sha}...)")

    # Dry-run check
    if args.dry_run:
        print("\n[Dry-run] No deletions performed.")
        return 0

    # Confirmation
    if not args.yes and not ask_yes_no("Proceed with DELETE?"):
        print("Aborted — nothing deleted.")
        return 0

    # Authenticate for DELETE
    user, password = get_credentials(args.user, args.password)
    auth_session = requests.Session()
    auth_session.auth = (user, password)

    # Collect blob URLs used by KEPT images (shared layers should not be deleted)
    kept_blob_urls: set = set()
    for item in kept:
        for asset in item.get("assets", []):
            url = asset.get("downloadUrl", "")
            if url and "blob" in url:
                kept_blob_urls.add(url)

    # Build delete URLs: blob layers first, then manifest references
    urls = []
    for item in to_delete:
        # Collect all blob layer download URLs from assets
        for asset in item.get("assets", []):
            url = asset.get("downloadUrl", "")
            if url and "blob" in url and url not in kept_blob_urls:
                urls.append(url)

        # Finally, delete the manifest reference itself
        sha = item.get("assets", [{}])[0].get("checksum", {}).get("sha256", "")
        if sha:
            urls.append(f"{base}/repository/{repo}/v2/{name}/manifests/sha256:{sha}")

    failures = delete_with_progress(auth_session, urls, label="Deleting Docker assets")
    print(f"\nDone. {len(urls) - failures}/{len(urls)} deleted successfully.")
    return 1 if failures else 0


def cmd_maven(args) -> int:
    """Search/delete Maven artifacts by group ID + version patterns.

    Uses /search with group=<groupId>, version=<pattern>. Deletes asset
    downloadUrls directly.
    """
    base = args.url.rstrip("/")
    repo = args.repo
    group = args.group
    version_patterns = args.versions

    session = requests.Session()
    if args.debug:
        print(f"Searching Maven artifacts in {repo} for {group}:{version_patterns}", file=sys.stderr)

    # Collect all matching assets across version patterns
    all_download_urls: List[str] = []
    for pattern in version_patterns:
        params = {
            "group": group,
        }
        # Omit version param when wildcard "*" — Nexus returns all versions
        if pattern != "*":
            params["version"] = pattern
        if repo:
            params["repository_name"] = repo
        items = paginate_search(session, base, params, debug=args.debug)
        for item in items:
            for asset in item.get("assets", []):
                url = asset.get("downloadUrl", "")
                if url and url not in all_download_urls:
                    all_download_urls.append(url)

    # Sort for consistent output
    all_download_urls.sort(reverse=args.reverse)

    if not all_download_urls:
        print("No Maven artifacts matched.")
        return 0

    print(f"\nFound {len(all_download_urls)} Maven asset(s) to delete:")
    for url in all_download_urls:
        print(f"  {url}")

    # Dry-run
    if args.dry_run:
        print("\n[Dry-run] No deletions performed.")
        return 0

    # Confirmation
    if not args.yes and not ask_yes_no("Proceed with DELETE?"):
        print("Aborted — nothing deleted.")
        return 0

    user, password = get_credentials(args.user, args.password)
    auth_session = requests.Session()
    auth_session.auth = (user, password)

    failures = delete_with_progress(auth_session, all_download_urls, label="Deleting Maven assets")
    print(f"\nDone. {len(all_download_urls) - failures}/{len(all_download_urls)} deleted successfully.")
    return 1 if failures else 0


def cmd_static(args) -> int:
    """Search/delete static assets (typically .txz frontend builds).

    Uses /search with repository_name=static, name=<type>/<module>/<version>.txz.
    Supports --keep N to retain latest versions.
    """
    base = args.url.rstrip("/")
    repo = args.repo or "static"
    module = args.module
    asset_type = args.type or "frontend"
    version_patterns = args.versions

    session = requests.Session()
    if args.debug:
        print(f"Searching static assets in {repo} for {asset_type}/{module}:{version_patterns}", file=sys.stderr)

    # Collect all matching items
    all_items: List[Dict[str, Any]] = []
    for pattern in version_patterns:
        name_query = f"{asset_type}/{module}/{pattern}.txz"
        params = {
            "repository_name": repo,
            "name": name_query,
        }
        items = paginate_search(session, base, params, debug=args.debug)
        for item in items:
            ver = item.get("version", "")
            item["_sort_key"] = extract_version_number(ver)
            all_items.append(item)

    # Deduplicate by downloadUrl
    seen_urls = set()
    unique_items: List[Dict[str, Any]] = []
    for item in all_items:
        for asset in item.get("assets", []):
            url = asset.get("downloadUrl", "")
            if url and url not in seen_urls:
                seen_urls.add(url)
                unique_items.append(item)
                break

    # Sort by version number
    unique_items.sort(key=lambda x: x["_sort_key"], reverse=args.reverse)

    # Apply --keep N
    kept: List[Dict[str, Any]] = []
    if args.keep is not None and len(unique_items) > args.keep:
        to_delete = unique_items[:-args.keep]
        kept = unique_items[-args.keep:]
        print(f"Keeping last {args.keep} version(s):")
        for k in kept:
            print(f"  [keep] {k.get('name', '?')}")
    elif args.keep is not None:
        # Total items <= keep count — nothing to delete
        kept = unique_items
        to_delete = []
    else:
        to_delete = unique_items

    if not to_delete:
        print("No static assets matched (or all retained by --keep).")
        return 0

    # Collect download URLs
    urls = []
    for item in to_delete:
        for asset in item.get("assets", []):
            url = asset.get("downloadUrl", "")
            if url:
                urls.append(url)
                break

    print(f"\nFound {len(urls)} static asset(s) to delete:")
    for url in urls:
        print(f"  {url}")

    # Dry-run
    if args.dry_run:
        print("\n[Dry-run] No deletions performed.")
        return 0

    # Confirmation
    if not args.yes and not ask_yes_no("Proceed with DELETE?"):
        print("Aborted — nothing deleted.")
        return 0

    user, password = get_credentials(args.user, args.password)
    auth_session = requests.Session()
    auth_session.auth = (user, password)

    failures = delete_with_progress(auth_session, urls, label="Deleting static assets")
    print(f"\nDone. {len(urls) - failures}/{len(urls)} deleted successfully.")
    return 1 if failures else 0


def cmd_generic(args) -> int:
    """Search/delete assets by path pattern (substring match).

    Uses /search/assets endpoint with repository + path query.
    Supports --keep N, sorting, and CSV/JSON output.
    """
    base = args.url.rstrip("/")
    repo = args.repo
    pattern = args.pattern

    session = requests.Session()
    if args.debug:
        print(f"Searching assets in {repo} for path containing '{pattern}'", file=sys.stderr)

    items = paginate_search_assets(session, base, {
        "repository": repo,
        "q": pattern,
    }, debug=args.debug)

    # Filter by case-insensitive path match
    filtered = [i for i in items if pattern.lower() in i.get("path", "").lower()]

    # Sort
    sort_key = args.sort_by
    if sort_key == "path":
        filtered.sort(key=lambda a: a.get("path", "").lower(), reverse=args.reverse)
    elif sort_key == "downloadUrl":
        filtered.sort(key=lambda a: a.get("downloadUrl", "").lower(), reverse=args.reverse)

    # Apply --keep N (keep last N after sorting)
    if args.keep is not None and len(filtered) > args.keep:
        to_delete = filtered[:-args.keep]
        kept = filtered[-args.keep:]
        print(f"Keeping last {args.keep} asset(s):")
        for k in kept:
            print(f"  [keep] {k['path']}")
    else:
        to_delete = filtered

    if not to_delete:
        print("No assets matched the pattern.")
        return 0

    # Output results
    if args.output == "json":
        print(json.dumps([{"path": i["path"], "downloadUrl": i["downloadUrl"]} for i in to_delete], indent=2))
    elif args.output == "csv":
        print("path,downloadUrl")
        for i in to_delete:
            print(f"{i['path']},{i['downloadUrl']}")
    else:
        print(f"\nFound {len(to_delete)} asset(s):")
        for i in to_delete:
            print(f"  {i['path']}")

    # Dry-run
    if args.dry_run:
        print("\n[Dry-run] No deletions performed.")
        return 0

    # Confirmation
    if not args.yes and not ask_yes_no("Proceed with DELETE?"):
        print("Aborted — nothing deleted.")
        return 0

    user, password = get_credentials(args.user, args.password)
    auth_session = requests.Session()
    auth_session.auth = (user, password)

    urls = [i["downloadUrl"] for i in to_delete]
    failures = delete_with_progress(auth_session, urls, label="Deleting assets")
    print(f"\nDone. {len(urls) - failures}/{len(urls)} deleted successfully.")
    return 1 if failures else 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="nexus-clean.py",
        description="Nexus Repository Manager artifact cleanup tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    # Global options
    parser.add_argument("-u", "--url", default=DEFAULT_URL,
                        help=f"Nexus base URL (default: {DEFAULT_URL} or $NEXUS_URL)")
    parser.add_argument("--user", default=os.getenv("NEXUS_USER"),
                        help="Nexus username (or $NEXUS_USER)")
    parser.add_argument("--password", default=os.getenv("NEXUS_PASS"),
                        help="Nexus password (or $NEXUS_PASS)")
    parser.add_argument("-y", "--yes", action="store_true",
                        help="Skip confirmation prompt")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview without deleting")
    parser.add_argument("--debug", action="store_true",
                        help="Print API request URLs to stderr")

    subparsers = parser.add_subparsers(dest="command", help="Repository type to clean")

    # --- docker ---
    docker = subparsers.add_parser("docker", help="Docker registry images")
    docker.add_argument("repo", help="Repository name (e.g. local-registry)")
    docker.add_argument("name", help="Image name/component (e.g. acc-backend)")
    docker.add_argument("versions", nargs="+", help="Version tag patterns (e.g. blue-* purple-*)")
    docker.add_argument("-r", "--reverse", action="store_true",
                        help="Reverse sort order (newest first)")
    docker.add_argument("--keep", type=int, default=None,
                        help="Keep last N versions (retention policy)")
    docker.set_defaults(func=cmd_docker)

    # --- maven ---
    maven = subparsers.add_parser("maven", help="Maven repository artifacts")
    maven.add_argument("repo", nargs="?", default=None,
                       help="Repository name (optional)")
    maven.add_argument("group", help="Maven group ID (e.g. br.com.example.acc)")
    maven.add_argument("versions", nargs="+", help="Version patterns (e.g. green-* purple.*)")
    maven.add_argument("-r", "--reverse", action="store_true",
                       help="Reverse sort order")
    maven.add_argument("--keep", type=int, default=None,
                       help="Keep last N assets (retention policy)")
    maven.set_defaults(func=cmd_maven)

    # --- static ---
    static = subparsers.add_parser("static", help="Static file assets (.txz builds)")
    static.add_argument("repo", nargs="?", default="static",
                        help="Repository name (default: static)")
    static.add_argument("module", help="Module name (e.g. core)")
    static.add_argument("versions", nargs="+", help="Version patterns (e.g. v1.2-*)")
    static.add_argument("--type", default="frontend",
                        help="Asset type prefix (default: frontend)")
    static.add_argument("-r", "--reverse", action="store_true",
                        help="Reverse sort order (newest first)")
    static.add_argument("--keep", type=int, default=None,
                        help="Keep last N versions (retention policy)")
    static.set_defaults(func=cmd_static)

    # --- generic ---
    generic = subparsers.add_parser("generic", help="Generic path-based search/delete")
    generic.add_argument("-r", "--repo", required=True, help="Repository name")
    generic.add_argument("-p", "--pattern", required=True, help="Path substring to match")
    generic.add_argument("--sort-by", choices=["path", "downloadUrl", "none"], default="path",
                         help="Sort output (default: path)")
    generic.add_argument("--reverse", action="store_true",
                         help="Reverse sort order")
    generic.add_argument("--keep", type=int, default=None,
                         help="Keep last N assets (retention policy)")
    generic.add_argument("--output", choices=["table", "csv", "json"], default="table",
                         help="Output format (default: table)")
    generic.set_defaults(func=cmd_generic)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # --yes implies --apply (skip confirmation)
    try:
        return args.func(args)
    except requests.exceptions.ConnectionError as e:
        print(f"ERROR: Cannot connect to Nexus at {args.url}: {e}", file=sys.stderr)
        return 1
    except requests.exceptions.HTTPError as e:
        print(f"ERROR: HTTP error from Nexus: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
        return 130


if __name__ == "__main__":
    sys.exit(main())
