#!/usr/bin/env bash
#
# gitStaleBranches.sh — List and delete stale remote git branches.
#
# Finds remote branches whose last commit is older than N months.
# Modern replacement for the old 2021 one-liner:
#   for branch in $(git branch -r)... | grep months | xargs git push origin --delete
#
# Usage:
#   ./gitStaleBranches.sh 4                    # List branches older than 4 months
#   ./gitStaleBranches.sh 4 --rm               # Delete them (asks for confirmation)
#   ./gitStaleBranches.sh 4 --rm --yes         # Delete without confirmation
#   ./gitStaleBranches.sh 6 --merged           # Only branches merged into the default branch
#   ./gitStaleBranches.sh 4 --author luis      # Only branches last touched by "luis"
#   ./gitStaleBranches.sh 4 --remote upstream  # Inspect another remote
#   ./gitStaleBranches.sh 4 --protect 'release/*' --protect staging
#   ./gitStaleBranches.sh 4 --quiet            # Print only branch names (for piping)
#
# Options:
#   --rm, --delete       Delete the branches on the remote (git push --delete)
#   --remote NAME        Remote to inspect (default: origin)
#   --merged             Only branches already merged into the remote default branch
#   --author PATTERN     Only branches whose last author matches PATTERN
#                        (case-insensitive substring)
#   --protect PATTERN    Additional protected branch (glob, repeatable).
#                        Always protected: remote default branch, master, main, develop
#   --no-fetch           Skip 'git fetch --prune' before inspecting
#   -y, --yes            Skip the confirmation prompt when deleting
#   -q, --quiet          Print only branch names, no table or summary
#   -h, --help           Show this help
#
# Exit codes:
#   0 — Success (including "nothing found")
#   1 — One or more deletions failed
#   2 — Usage / environment error

set -euo pipefail

# ── Color helpers (disabled if not a terminal) ──────────────────────────────
if [[ -t 2 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

log()  { $QUIET || echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'
}

# ── Argument parsing ────────────────────────────────────────────────────────
MONTHS=""
DO_DELETE=false
REMOTE="origin"
MERGED_ONLY=false
AUTHOR_FILTER=""
EXTRA_PROTECT=()
NO_FETCH=false
ASSUME_YES=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rm|--delete)  DO_DELETE=true ;;
        --remote)       REMOTE="${2:?--remote needs a value}"; shift ;;
        --merged)       MERGED_ONLY=true ;;
        --author)       AUTHOR_FILTER="${2:?--author needs a value}"; shift ;;
        --protect)      EXTRA_PROTECT+=("${2:?--protect needs a value}"); shift ;;
        --no-fetch)     NO_FETCH=true ;;
        -y|--yes)       ASSUME_YES=true ;;
        -q|--quiet)     QUIET=true ;;
        -h|--help)      usage; exit 0 ;;
        -*)             err "Unknown option: $1"; usage >&2; exit 2 ;;
        *)
            if [[ -n "$MONTHS" ]]; then
                err "Unexpected argument: $1 (months already set to $MONTHS)"
                exit 2
            fi
            MONTHS="$1"
            ;;
    esac
    shift
done

if [[ -z "$MONTHS" ]]; then
    usage >&2
    exit 2
fi
if ! [[ "$MONTHS" =~ ^[0-9]+$ ]] || [[ "$MONTHS" -eq 0 ]]; then
    err "N must be a positive integer number of months (got: $MONTHS)"
    exit 2
fi

# ── Environment checks ──────────────────────────────────────────────────────
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    err "Not inside a git repository."
    exit 2
fi
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    err "Remote '$REMOTE' does not exist in this repository."
    exit 2
fi
if ! CUTOFF_EPOCH=$(date -d "$MONTHS months ago" +%s 2>/dev/null); then
    err "This script needs GNU date (date -d '... months ago')."
    exit 2
fi
CUTOFF_DATE=$(date -d "$MONTHS months ago" +%Y-%m-%d)

# ── Refresh remote refs ─────────────────────────────────────────────────────
if ! $NO_FETCH; then
    log "Fetching '$REMOTE' (with --prune)..."
    if ! git fetch --prune --quiet "$REMOTE"; then
        if $DO_DELETE; then
            err "git fetch failed — refusing to delete based on stale local data." \
                "Fix connectivity or pass --no-fetch to override."
            exit 2
        fi
        warn "git fetch failed — listing from possibly stale local refs."
    fi
fi

# ── Protected branches ──────────────────────────────────────────────────────
# Detect the remote default branch (what origin/HEAD points to).
DEFAULT_BRANCH=""
head_ref=$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" || true)
if [[ -z "$head_ref" ]] && ! $NO_FETCH; then
    git remote set-head "$REMOTE" --auto >/dev/null 2>&1 || true
    head_ref=$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" || true)
fi
[[ -n "$head_ref" ]] && DEFAULT_BRANCH="${head_ref#"$REMOTE"/}"

PROTECTED=(master main develop)
[[ -n "$DEFAULT_BRANCH" ]] && PROTECTED+=("$DEFAULT_BRANCH")
PROTECTED+=("${EXTRA_PROTECT[@]}")

is_protected() {
    local branch="$1" pattern
    for pattern in "${PROTECTED[@]}"; do
        # shellcheck disable=SC2053  # unquoted RHS is intentional: glob match
        [[ "$branch" == $pattern ]] && return 0
    done
    return 1
}

# ── Collect stale branches ──────────────────────────────────────────────────
FER_ARGS=(--sort=committerdate
          --format='%(committerdate:unix)%09%(committerdate:short)%09%(committerdate:relative)%09%(authorname)%09%(refname)')
if $MERGED_ONLY; then
    if [[ -z "$DEFAULT_BRANCH" ]]; then
        err "--merged needs the remote default branch, which could not be detected." \
            "Run: git remote set-head $REMOTE --auto"
        exit 2
    fi
    FER_ARGS+=(--merged "refs/remotes/$REMOTE/$DEFAULT_BRANCH")
fi

BRANCHES=()   # branch names eligible for deletion
ROWS=()       # tab-separated display rows, same order
total_scanned=0
while IFS=$'\t' read -r epoch date_short relative author ref; do
    [[ -z "$ref" ]] && continue
    branch="${ref#refs/remotes/"$REMOTE"/}"
    [[ "$branch" == "HEAD" ]] && continue
    total_scanned=$((total_scanned + 1))
    is_protected "$branch" && continue
    [[ "$epoch" -ge "$CUTOFF_EPOCH" ]] && continue
    if [[ -n "$AUTHOR_FILTER" && "${author,,}" != *"${AUTHOR_FILTER,,}"* ]]; then
        continue
    fi
    BRANCHES+=("$branch")
    ROWS+=("${date_short}"$'\t'"${relative}"$'\t'"${author}"$'\t'"${branch}")
done < <(git for-each-ref "${FER_ARGS[@]}" "refs/remotes/$REMOTE/")

if [[ $total_scanned -eq 0 ]]; then
    warn "No remote-tracking branches found for '$REMOTE'." \
         "Try running without --no-fetch, or check the remote."
    exit 0
fi

# ── Report ──────────────────────────────────────────────────────────────────
if [[ ${#BRANCHES[@]} -eq 0 ]]; then
    log "No branches on '$REMOTE' older than $MONTHS month(s)." \
        "(scanned $total_scanned, cutoff: $CUTOFF_DATE)"
    exit 0
fi

if $QUIET; then
    printf '%s\n' "${BRANCHES[@]}"
else
    printf '%-12s %-22s %-22s %s\n' "LAST COMMIT" "AGE" "AUTHOR" "BRANCH"
    while IFS=$'\t' read -r date_short relative author branch; do
        printf '%-12s %-22s %-22.22s %s\n' "$date_short" "$relative" "$author" "$branch"
    done < <(printf '%s\n' "${ROWS[@]}")
    echo
    log "${#BRANCHES[@]} of $total_scanned branches on '$REMOTE' are older" \
        "than $MONTHS month(s) (cutoff: $CUTOFF_DATE)."
fi

if ! $DO_DELETE; then
    $QUIET || log "Run again with --rm to delete them."
    exit 0
fi

# ── Delete ──────────────────────────────────────────────────────────────────
if ! $ASSUME_YES; then
    prompt="Delete these ${#BRANCHES[@]} branches from '$REMOTE'? [y/N] "
    if [[ -t 0 ]]; then
        read -r -p "$prompt" answer
    elif [[ -r /dev/tty ]]; then
        read -r -p "$prompt" answer </dev/tty
    else
        err "No terminal available for confirmation — use --yes to delete non-interactively."
        exit 2
    fi
    if ! [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
        log "Aborted — nothing deleted."
        exit 0
    fi
fi

CHUNK_SIZE=50
deleted=0
FAILED=()
for ((i = 0; i < ${#BRANCHES[@]}; i += CHUNK_SIZE)); do
    chunk=("${BRANCHES[@]:i:CHUNK_SIZE}")
    log "Deleting branches $((i + 1))-$((i + ${#chunk[@]})) of ${#BRANCHES[@]}..."
    if git push "$REMOTE" --delete "${chunk[@]}"; then
        deleted=$((deleted + ${#chunk[@]}))
    else
        # A batch push may partially succeed: retry each branch, but first
        # check whether it is already gone from the remote.
        warn "Batch delete failed — retrying this batch branch by branch..."
        for branch in "${chunk[@]}"; do
            if ! git ls-remote --exit-code --heads "$REMOTE" "refs/heads/$branch" >/dev/null 2>&1; then
                deleted=$((deleted + 1))   # already gone (deleted in the failed batch)
            elif git push "$REMOTE" --delete "$branch"; then
                deleted=$((deleted + 1))
            else
                FAILED+=("$branch")
            fi
        done
    fi
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
    err "Deleted $deleted, failed ${#FAILED[@]}:"
    printf '  %s\n' "${FAILED[@]}" >&2
    exit 1
fi
log "Deleted $deleted branch(es) from '$REMOTE'."
