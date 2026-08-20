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
#   --rm, --delete       Delete the branches on the remote (see SAFETY below)
#   --remote NAME        Remote to inspect (default: origin)
#   --merged             Only branches already merged into the remote default branch
#   --author PATTERN     Only branches whose last author matches PATTERN
#                        (case-insensitive substring)
#   --protect PATTERN    Additional protected branch (glob, repeatable).
#                        Always protected: remote default branch, master, main, develop
#   --no-fetch           Skip 'git fetch --prune' before inspecting
#   --no-lease           Delete without pinning to the scanned commit (see SAFETY)
#   -y, --yes            Skip the confirmation prompt when deleting
#   -q, --quiet          Print only branch names, no table or summary
#   -h, --help           Show this help
#
# Safety:
#   * Deletions are pinned to the exact commit seen during the scan
#     (git push --force-with-lease). If someone pushes to a branch between the
#     scan and the delete, the remote rejects it as "stale info" and the branch
#     survives — it is reported as skipped. --no-lease disables this.
#   * Branches are deleted via the explicit ':refs/heads/<name>' refspec, so a
#     branch named '-n' or one sharing its name with a tag cannot misfire.
#   * The remote default branch is read from the remote itself (ls-remote
#     --symref), not from a possibly stale local origin/HEAD.
#
# Note on "age": staleness is the committer date of the branch tip. A branch
# pushed today whose tip is an old commit (e.g. cherry-picked or rebased onto
# old history) counts as stale — the remote does not expose branch creation
# dates. --no-lease removes the tripwire that would otherwise catch this.
#
# Exit codes:
#   0 — Success (including "nothing found" and lease-skipped branches)
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
USE_LEASE=true
ASSUME_YES=false
QUIET=false

# Usage errors must exit 2, so validate option values explicitly instead of
# relying on ${2:?...} (which exits 1 with a raw bash diagnostic).
need_val() {  # need_val <flag> [<value> ...]
    if [[ $# -lt 2 || -z "$2" ]]; then
        err "Option $1 requires a non-empty value."
        exit 2
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rm|--delete)  DO_DELETE=true ;;
        --remote)       need_val "$@"; REMOTE="$2"; shift ;;
        --merged)       MERGED_ONLY=true ;;
        --author)       need_val "$@"; AUTHOR_FILTER="$2"; shift ;;
        --protect)      need_val "$@"; EXTRA_PROTECT+=("$2"); shift ;;
        --no-fetch)     NO_FETCH=true ;;
        --no-lease)     USE_LEASE=false ;;
        -y|--yes)       ASSUME_YES=true ;;
        -q|--quiet)     QUIET=true ;;
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
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
if [[ $# -gt 0 && -z "$MONTHS" ]]; then
    MONTHS="$1"
fi

if [[ -z "$MONTHS" ]]; then
    usage >&2
    exit 2
fi
# 1-4 digits keeps $((10#…)) inside integer range; 10# avoids octal parsing of "08".
if ! [[ "$MONTHS" =~ ^[0-9]{1,4}$ ]] || (( 10#$MONTHS == 0 )); then
    err "N must be a positive integer number of months, 1-9999 (got: $MONTHS)"
    exit 2
fi
MONTHS=$((10#$MONTHS))

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

# A --single-branch clone only tracks one branch, so the scan would silently
# see almost nothing.
if ! git config --get-all "remote.$REMOTE.fetch" | grep -q 'refs/heads/\*'; then
    warn "remote.$REMOTE.fetch does not cover refs/heads/* (single-branch clone?)." \
         "Results may be incomplete — fix with:" \
         "git config --replace-all remote.$REMOTE.fetch '+refs/heads/*:refs/remotes/$REMOTE/*'"
fi

# ── Refresh remote refs ─────────────────────────────────────────────────────
if ! $NO_FETCH; then
    log "Fetching '$REMOTE' (with --prune)..."
    if ! git fetch --prune --quiet "$REMOTE"; then
        if $DO_DELETE; then
            err "git fetch failed — refusing to delete based on stale local data." \
                "Fix connectivity, or pass --no-fetch to accept the risk."
            exit 2
        fi
        warn "git fetch failed — listing from possibly stale local refs."
    fi
fi

# ── Protected branches ──────────────────────────────────────────────────────
# Ask the remote what its default branch is. A local origin/HEAD can dangle
# (e.g. the default was renamed server-side), which would leave the real
# default branch unprotected.
DEFAULT_BRANCH=""
DEFAULT_SRC=""
if ! $NO_FETCH; then
    remote_head=$(git ls-remote --symref "$REMOTE" HEAD 2>/dev/null \
                  | awk '$1 == "ref:" { print $2; exit }' || true)
    if [[ -n "$remote_head" ]]; then
        DEFAULT_BRANCH="${remote_head#refs/heads/}"
        DEFAULT_SRC="remote"
    fi
fi
if [[ -z "$DEFAULT_BRANCH" ]]; then
    head_ref=$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" || true)
    if [[ -n "$head_ref" ]]; then
        candidate="${head_ref#"$REMOTE"/}"
        # Only trust the local symref if it still resolves.
        if git rev-parse -q --verify "refs/remotes/$REMOTE/$candidate^{commit}" >/dev/null; then
            DEFAULT_BRANCH="$candidate"
            DEFAULT_SRC="local"
        else
            warn "Local refs/remotes/$REMOTE/HEAD points at '$candidate', which no longer exists" \
                 "(default branch renamed on the remote?)."
            if $DO_DELETE; then
                err "Cannot confirm the remote default branch, so it cannot be protected." \
                    "Refusing to delete. Fix with: git remote set-head $REMOTE --auto"
                exit 2
            fi
        fi
    fi
fi
if [[ -z "$DEFAULT_BRANCH" ]]; then
    warn "Could not determine the default branch of '$REMOTE'." \
         "Only master/main/develop (plus any --protect) are protected."
fi

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
# %(refname) comes first and %(authorname) last: an author name may itself
# contain a tab, and read's last variable absorbs the remainder harmlessly.
FER_ARGS=(--sort=committerdate
          --format='%(refname)%09%(objectname)%09%(committerdate:unix)%09%(committerdate:short)%09%(committerdate:relative)%09%(authorname)')
if $MERGED_ONLY; then
    if [[ -z "$DEFAULT_BRANCH" ]]; then
        err "--merged needs the remote default branch, which could not be detected." \
            "Run: git remote set-head $REMOTE --auto"
        exit 2
    fi
    MERGE_BASE_REF="refs/remotes/$REMOTE/$DEFAULT_BRANCH"
    if ! git rev-parse -q --verify "$MERGE_BASE_REF^{commit}" >/dev/null; then
        err "--merged needs a local copy of '$DEFAULT_BRANCH' ($MERGE_BASE_REF is missing)." \
            "Run without --no-fetch, or fetch the remote first."
        exit 2
    fi
    FER_ARGS+=(--merged "$MERGE_BASE_REF")
fi

# Collect via a temp file: a failing for-each-ref inside <(...) would be
# invisible to set -e and look like "no branches found".
REFS_FILE=$(mktemp "${TMPDIR:-/tmp}/gitStaleBranches.XXXXXX")
trap 'rm -f "$REFS_FILE"' EXIT
if ! git for-each-ref "${FER_ARGS[@]}" "refs/remotes/$REMOTE/" >"$REFS_FILE"; then
    err "git for-each-ref failed — cannot enumerate branches of '$REMOTE'."
    exit 2
fi

BRANCHES=()   # branch names eligible for deletion
OIDS=()       # commit each branch pointed at during the scan (same order)
ROWS=()       # tab-separated display rows (same order)
total_scanned=0
while IFS=$'\t' read -r ref oid epoch date_short relative author; do
    [[ -z "$ref" || -z "$oid" ]] && continue
    branch="${ref#refs/remotes/"$REMOTE"/}"
    [[ "$branch" == "HEAD" || "$branch" == "$ref" ]] && continue
    total_scanned=$((total_scanned + 1))
    is_protected "$branch" && continue
    [[ "$epoch" -ge "$CUTOFF_EPOCH" ]] && continue
    if [[ -n "$AUTHOR_FILTER" && "${author,,}" != *"${AUTHOR_FILTER,,}"* ]]; then
        continue
    fi
    BRANCHES+=("$branch")
    OIDS+=("$oid")
    ROWS+=("${date_short}"$'\t'"${relative}"$'\t'"${author}"$'\t'"${branch}")
done <"$REFS_FILE"

if [[ $total_scanned -eq 0 ]]; then
    warn "No remote-tracking branches found for '$REMOTE'." \
         "Try running without --no-fetch, or check the remote."
    exit 0
fi

# ── Report ──────────────────────────────────────────────────────────────────
FILTER_DESC=""
$MERGED_ONLY && FILTER_DESC="${FILTER_DESC}, merged into $DEFAULT_BRANCH"
[[ -n "$AUTHOR_FILTER" ]] && FILTER_DESC="${FILTER_DESC}, author matching '$AUTHOR_FILTER'"

if [[ ${#BRANCHES[@]} -eq 0 ]]; then
    log "No branches on '$REMOTE' older than $MONTHS month(s)${FILTER_DESC}." \
        "(scanned $total_scanned, cutoff: $CUTOFF_DATE)"
    exit 0
fi

if $QUIET; then
    printf '%s\n' "${BRANCHES[@]}"
else
    printf '%-12s %-22s %-22s %s\n' "LAST COMMIT" "AGE" "AUTHOR" "BRANCH"
    while IFS=$'\t' read -r date_short relative author branch; do
        # Slice by characters, not bytes: %.Ns would cut UTF-8 names mid-sequence.
        printf '%-12s %-22s %-22s %s\n' \
            "$date_short" "$relative" "${author:0:22}" "$branch"
    done < <(printf '%s\n' "${ROWS[@]}")
    echo
    log "${#BRANCHES[@]} of $total_scanned branches on '$REMOTE' are older" \
        "than $MONTHS month(s)${FILTER_DESC} (cutoff: $CUTOFF_DATE)."
fi

if ! $DO_DELETE; then
    $QUIET || log "Run again with --rm to delete them."
    exit 0
fi

# ── Delete ──────────────────────────────────────────────────────────────────
if ! $ASSUME_YES; then
    prompt="Delete these ${#BRANCHES[@]} branches from '$REMOTE'? [y/N] "
    answer=""
    if [[ -t 0 ]]; then
        read -r -p "$prompt" answer || true
    elif { : </dev/tty; } 2>/dev/null; then
        read -r -p "$prompt" answer </dev/tty || true
    else
        err "No terminal available for confirmation — use --yes to delete non-interactively."
        exit 2
    fi
    if ! [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
        log "Aborted — nothing deleted."
        exit 0
    fi
fi

# Fully-qualified refspecs: a branch named '-n' is never read as an option, and
# a same-named tag is never a candidate for the deletion.
push_args_for() {  # push_args_for <index>...
    local i
    PUSH_ARGS=()
    for i in "$@"; do
        $USE_LEASE && PUSH_ARGS+=("--force-with-lease=refs/heads/${BRANCHES[i]}:${OIDS[i]}")
    done
    for i in "$@"; do
        PUSH_ARGS+=(":refs/heads/${BRANCHES[i]}")
    done
}

CHUNK_SIZE=50
deleted=0
FAILED=()
SKIPPED=()
network_error=false

start=0
while (( start < ${#BRANCHES[@]} )); do
    $network_error && break
    idx=()
    for ((i = start; i < start + CHUNK_SIZE && i < ${#BRANCHES[@]}; i++)); do
        idx+=("$i")
    done
    log "Deleting branches $((start + 1))-$((start + ${#idx[@]})) of ${#BRANCHES[@]}..."
    push_args_for "${idx[@]}"
    if git push "$REMOTE" "${PUSH_ARGS[@]}"; then
        deleted=$((deleted + ${#idx[@]}))
    else
        # A batch push is all-or-nothing per ref, so re-check each branch
        # against the remote and classify it before retrying.
        warn "Batch delete failed — checking each branch against the remote..."
        for i in "${idx[@]}"; do
            branch="${BRANCHES[i]}"
            rc=0
            remote_line=$(git ls-remote --exit-code --heads "$REMOTE" \
                          "refs/heads/$branch" 2>/dev/null) || rc=$?
            case "$rc" in
                0)  ;;                                  # still there
                2)  deleted=$((deleted + 1)); continue ;;   # already gone
                *)  err "Cannot reach '$REMOTE' (git ls-remote exit $rc) — aborting."
                    network_error=true
                    break ;;
            esac
            remote_oid="${remote_line%%$'\t'*}"
            if $USE_LEASE && [[ "$remote_oid" != "${OIDS[i]}" ]]; then
                SKIPPED+=("$branch")
                continue
            fi
            push_args_for "$i"
            if git push "$REMOTE" "${PUSH_ARGS[@]}"; then
                deleted=$((deleted + 1))
            else
                FAILED+=("$branch")
            fi
        done
    fi
    start=$((start + CHUNK_SIZE))
done

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    warn "Skipped ${#SKIPPED[@]} branch(es) — new commits were pushed after the scan:"
    printf '  %s\n' "${SKIPPED[@]}" >&2
fi
if $network_error || [[ ${#FAILED[@]} -gt 0 ]]; then
    remaining=$(( ${#BRANCHES[@]} - deleted - ${#SKIPPED[@]} ))
    err "Deleted $deleted of ${#BRANCHES[@]}; $remaining not deleted."
    [[ ${#FAILED[@]} -gt 0 ]] && printf '  %s\n' "${FAILED[@]}" >&2
    exit 1
fi
log "Deleted $deleted branch(es) from '$REMOTE'."
