#!/usr/bin/env python3
"""
nexusRMgeneric.py  –  list & optionally delete assets whose *path* matches PATTERN
This script connects to a Nexus Repository Manager instance, searches for assets
whose path matches a given pattern, and optionally deletes them after user confirmation.

Usage:
    python3 nexusRMgeneric.py -u https://repo.techsytes.com -r rhel-10-techsytes -p "-73" --user admin --password 123 --apply
"""
import argparse, getpass, os, sys, requests
# progress bar (optional)
try:
    from tqdm import tqdm          # pip install tqdm
except ImportError:                 # fallback banner if tqdm missing
    tqdm = None


SEARCH = "/service/rest/v1/search/assets"

def collect(session, base, repo, pattern, debug=False):
    items, token = [], None
    while True:
        params = {"repository": repo, "q": pattern}
        if token:
            params["continuationToken"] = token

        r = session.get(base + SEARCH, params=params, timeout=30)
        if debug:
            print("DEBUG search:", r.url, "→", r.status_code)
        r.raise_for_status()
        data = r.json()
        items.extend(data.get("items", []))
        token = data.get("continuationToken")
        if not token:
            break
    return items

def ask_yes_no(q, default=False):
    if default:   # --yes, -y
        return True
    ans = input(f"{q} [y/N] ").strip().lower()
    return ans.startswith("y")

def delete_assets(session, assets):
    total = len(assets)
    progress = tqdm(total=total, unit="pkg") if tqdm else None
    for idx, a in enumerate(assets, 1):
        url = a["downloadUrl"]
        resp = session.delete(url, timeout=30)
        ok = resp.ok
        msg = f"{'✔' if ok else '✖'} {idx:>4}/{total}  {url}"
        if progress:
            progress.set_description(msg[:140])
            progress.update(1)
        else:
            print(msg)
    if progress:
        progress.close()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-u", "--url", default="https://repo.techsytes.com",
                    help="Nexus base URL")
    ap.add_argument("-r", "--repo", required=True, help="Repository")
    ap.add_argument("-p", "--pattern", required=True, help="Substring/glob")
    ap.add_argument("--user", default=os.getenv("NEXUS_USER"))
    ap.add_argument("--password", default=os.getenv("NEXUS_PASS"))
    ap.add_argument("--apply", action="store_true",
                    help="After confirmation, DELETE the assets")
    ap.add_argument("-y", "--yes", action="store_true",
                    help="Skip confirmation prompt (implies --apply)")
    ap.add_argument("--debug", action="store_true")
    ap.add_argument("--sort-by", choices=["path","url","none"], default="path",
                    help="Sort output before printing/deleting (default: path).")
    ap.add_argument("--reverse", action="store_true",
                    help="Reverse sort order.")
    args = ap.parse_args()

    # anonymous session for search
    anon = requests.Session()
    base = args.url.rstrip("/")

    if args.debug:
        print("Searching…")
    items = collect(anon, base, args.repo, args.pattern, debug=args.debug)

    # sort before display (and delete)
    if args.sort_by == "path":
        items.sort(key=lambda a: a["path"].lower(), reverse=args.reverse)
    elif args.sort_by == "url":
        items.sort(key=lambda a: a["downloadUrl"].lower(), reverse=args.reverse)
    # "none" leaves server order

    if not items:
        print("No assets matched the pattern.")
        return 0

    print(f"Found {len(items)} asset(s):")
    for i in items:
        print(" •", i["path"])

    if not args.apply and not args.yes:
        return 0          # listing mode only

    # need credentials for DELETE
    if not args.user:
        args.user = input("Nexus user: ")
    if not args.password:
        args.password = getpass.getpass("Nexus password: ")

    if not args.yes and not ask_yes_no("Proceed with DELETE?"):
        print("Abort – nothing deleted.")
        return 0

    auth_sess = requests.Session()
    auth_sess.auth = (args.user, args.password)
    delete_assets(auth_sess, items)
    return 0

if __name__ == "__main__":
    sys.exit(main())
