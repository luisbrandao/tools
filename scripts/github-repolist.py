#!/usr/bin/env python3
"""
List all repositories from a GitHub organization and print their SSH URLs.

Usage examples:
    # Using command-line arguments
    python github-repolist.py --org myorg --token ghp_xxxx

    # Using environment variable for the token (recommended)
    export GH_TOKEN=ghp_xxxx
    python github-repolist.py --org myorg

    # Pipe output to git clone
    python github-repolist.py --org myorg | xargs -I{} git clone {}
"""

import argparse
import os
import sys

try:
    import requests
except ImportError:
    print("Error: 'requests' library is required. Install it with:", file=sys.stderr)
    print("  pip install requests", file=sys.stderr)
    sys.exit(1)


def fetch_repos(org, token):
    """Fetch all repositories for an organization, handling pagination."""
    url = f"https://api.github.com/orgs/{org}/repos"
    headers = {
        "Authorization": f"token {token}",
        "User-Agent": "github-repolist-py",
        "Accept": "application/vnd.github.v3+json",
    }

    repos = []
    page = 1
    per_page = 100

    while True:
        params = {"per_page": per_page, "page": page}
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()

        batch = response.json()
        if not batch:
            break

        repos.extend(batch)
        page += 1

    return repos


def main():
    parser = argparse.ArgumentParser(
        description="List SSH URLs of all repositories in a GitHub organization."
    )
    parser.add_argument("--org", required=True, help="GitHub organization name")
    parser.add_argument(
        "--token",
        default=os.environ.get("GH_TOKEN"),
        help="GitHub personal access token (or set GH_TOKEN env var)",
    )
    parser.add_argument(
        "--protocol",
        choices=["ssh", "https"],
        default="ssh",
        help="URL protocol to output (default: ssh)",
    )
    args = parser.parse_args()

    if not args.token:
        print(
            "Error: No token provided. Use --token or set GH_TOKEN environment variable.",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        repos = fetch_repos(args.org, args.token)
    except requests.exceptions.HTTPError as exc:
        status = exc.response.status_code
        if status == 404:
            print(f"Error: Organization '{args.org}' not found.", file=sys.stderr)
        elif status == 401:
            print("Error: Invalid token or unauthorized.", file=sys.stderr)
        else:
            print(f"Error: GitHub API returned status {status}.", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.RequestException as exc:
        print(f"Error: Request failed - {exc}", file=sys.stderr)
        sys.exit(1)

    url_key = "ssh_url" if args.protocol == "ssh" else "clone_url"
    for repo in repos:
        print(repo.get(url_key, ""))


if __name__ == "__main__":
    main()
