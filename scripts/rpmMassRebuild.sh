#!/usr/bin/env bash
#
# rpmMassRebuild.sh — Mass-rebuild Source RPMs in a directory.
#
# Installs build dependencies (dnf builddep) then rebuilds each .src.rpm
# found in the target directory. Successfully rebuilt SRPMs are optionally
# removed after building.
#
# Usage:
#   ./rpmMassRebuild.sh                          # Rebuild all .src.rpm in cwd
#   ./rpmMassRebuild.sh /path/to/srpms           # Rebuild SRPMs in a specific dir
#   ./rpmMassRebuild.sh --dir /path/to/srpms     # Same as above (explicit flag)
#   ./rpmMassRebuild.sh --dry-run                # Preview without building
#   ./rpmMassRebuild.sh --keep                   # Don't remove SRPMs after build
#   ./rpmMassRebuild.sh --jobs 4                 # Parallel builds (up to 4 at once)
#   ./rpmMassRebuild.sh --arch x86_64            # Override target architecture
#
# Exit codes:
#   0 — All SRPMs rebuilt successfully (or no SRPMs found)
#   1 — One or more builds failed
#   2 — Usage / argument error

set -euo pipefail

# ── Defaults ────────────────────────────────────────────────────────────────
DIR="."
DRY_RUN=false
KEEP=false
JOBS=1
ARCH=""
LOG_FILE=""
DEBUG_PACKAGE="%{nil}"  # Disable debuginfo packages by default

# ── Color helpers (disabled if not a terminal) ──────────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# ── Logging ─────────────────────────────────────────────────────────────────
log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Usage ───────────────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
rpmMassRebuild.sh — Mass-rebuild Source RPMs in a directory.

SYNOPSIS:
    rpmMassRebuild.sh [OPTIONS] [DIRECTORY]

OPTIONS:
    -d, --dir DIR       Directory containing .src.rpm files (default: cwd)
    -n, --dry-run       Preview SRPMs without building
    -k, --keep          Keep SRPMs after successful build (default: remove)
    -j, --jobs N        Number of parallel builds (default: 1, max: CPU count)
    -a, --arch ARCH     Override target architecture for rpmbuild
    -l, --log FILE      Write build log to FILE
    --debug-info        Include debuginfo packages in build
    -h, --help          Show this help message

EXAMPLES:
    # Rebuild all SRPMs in current directory
    ./rpmMassRebuild.sh

    # Dry run on a specific directory
    ./rpmMassRebuild.sh --dry-run /var/rpms/SRPMS

    # Parallel rebuild with 4 jobs, keep SRPMs
    ./rpmMassRebuild.sh -j 4 --keep /path/to/srpms

    # Build with debuginfo packages included
    ./rpmMassRebuild.sh --debug-info

EOF
}

# ── Argument parsing ────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                DIR="$2"; shift 2 ;;
            -n|--dry-run)
                DRY_RUN=true; shift ;;
            -k|--keep)
                KEEP=true; shift ;;
            -j|--jobs)
                JOBS="$2"; shift 2 ;;
            -a|--arch)
                ARCH="$2"; shift 2 ;;
            -l|--log)
                LOG_FILE="$2"; shift 2 ;;
            --debug-info)
                DEBUG_PACKAGE=""; shift ;;
            -h|--help)
                usage; exit 0 ;;
            -*)
                err "Unknown option: $1"
                usage >&2; exit 2 ;;
            *)
                DIR="$1"; shift ;;
        esac
    done

    # Validate directory
    if [[ ! -d "$DIR" ]]; then
        err "Directory not found: $DIR"
        exit 2
    fi

    # Validate jobs count
    local cpus
    cpus=$(nproc 2>/dev/null || echo 1)
    if [[ "$JOBS" -lt 1 ]]; then
        err "Jobs must be >= 1"
        exit 2
    fi
    if [[ "$JOBS" -gt "$cpus" ]]; then
        warn "Requested $JOBS jobs but only $cpus CPUs available, capping to $cpus"
        JOBS="$cpus"
    fi
}

# ── Build a single SRPM ────────────────────────────────────────────────────
build_srpm() {
    local srpm="$1"
    local defines="-D 'debug_package ${DEBUG_PACKAGE}'"

    if [[ -n "$ARCH" ]]; then
        defines="${defines} --target ${ARCH}"
    fi

    log "Installing build dependencies: $(basename "$srpm")"
    if ! dnf builddep -y "$srpm" 2>&1 | tee -a "${LOG_FILE:-/dev/null}"; then
        err "builddep failed for: $srpm"
        return 1
    fi

    log "Building: $(basename "$srpm")"
    if ! rpmbuild -bs --rebuild $defines "$srpm" 2>&1 | tee -a "${LOG_FILE:-/dev/null}"; then
        err "Build failed for: $srpm"
        return 1
    fi

    log "Built successfully: $(basename "$srpm")"
    return 0
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    # Find all SRPMs
    local -a srpm_list=()
    while IFS= read -r -d '' file; do
        srpm_list+=("$file")
    done < <(find "$DIR" -maxdepth 1 -name '*.src.rpm' -print0 2>/dev/null | sort -z)

    local total=${#srpm_list[@]}

    if [[ "$total" -eq 0 ]]; then
        warn "No .src.rpm files found in $DIR"
        exit 0
    fi

    log "Found $total SRPM(s) in $DIR"
    if [[ "$JOBS" -gt 1 ]]; then
        log "Using $JOBS parallel job(s)"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        warn "*** DRY RUN — no builds will be performed ***"
        echo ""
    fi

    # List SRPMs
    for srpm in "${srpm_list[@]}"; do
        local size
        size=$(stat -c%s "$srpm" 2>/dev/null || echo "?")
        echo "  $(basename "$srpm") (${size} bytes)"
    done

    if [[ "$DRY_RUN" == true ]]; then
        exit 0
    fi

    # Build SRPMs
    local failed=0
    local success=0
    local start_time
    start_time=$(date +%s)

    if [[ "$JOBS" -eq 1 ]]; then
        # Sequential builds
        for srpm in "${srpm_list[@]}"; do
            echo ""
            if build_srpm "$srpm"; then
                ((success++)) || true
                if [[ "$KEEP" == false ]]; then
                    rm -f "$srpm"
                    log "Removed: $(basename "$srpm")"
                fi
            else
                ((failed++)) || true
            fi
        done
    else
        # Parallel builds using xargs
        local fail_file success_file
        fail_file=$(mktemp)
        success_file=$(mktemp)
        trap 'rm -f "$fail_file" "$success_file"' EXIT

        printf '%s\0' "${srpm_list[@]}" | xargs -0 -P "$JOBS" -I {} bash -c '
            srpm="$1"
            defines="-D '\''debug_package ${DEBUG_PACKAGE}'\''"; 
            if [[ -n "'"${ARCH}"'" ]]; then
                defines="${defines} --target "'"${ARCH}"'";
            fi
            
            echo "[INFO] Installing build deps: $(basename "$srpm")"
            if ! dnf builddep -y "$srpm" >/dev/null 2>&1; then
                echo "FAIL:$srpm" >> "'"${fail_file}"'"
                exit 0
            fi
            
            echo "[INFO] Building: $(basename "$srpm")"
            if ! rpmbuild -bs --rebuild $defines "$srpm" >/dev/null 2>&1; then
                echo "FAIL:$srpm" >> "'"${fail_file}"'"
                exit 0
            fi
            
            echo "OK:$srpm" >> "'"${success_file}"'"
        ' _ {}

        # Count results
        failed=$(wc -l < "$fail_file" 2>/dev/null || echo 0)
        success=$(wc -l < "$success_file" 2>/dev/null || echo 0)

        # Clean up successful SRPMs if not keeping
        if [[ "$KEEP" == false ]]; then
            while IFS= read -r line; do
                local srpm="${line#OK:}"
                rm -f "$srpm"
            done < "$success_file"
        fi

        # Report failures
        if [[ -s "$fail_file" ]]; then
            echo ""
            err "Failed builds:"
            while IFS= read -r line; do
                local srpm="${line#FAIL:}"
                err "  $(basename "$srpm")"
            done < "$fail_file"
        fi
    fi

    # Summary
    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))

    echo ""
    echo "=================================================="
    echo "Build Summary"
    echo "=================================================="
    echo "Total SRPMs:    $total"
    echo "Successful:     $success"
    echo "Failed:         $failed"
    echo "Time elapsed:   ${elapsed}s"
    if [[ "$KEEP" == true ]]; then
        echo "SRPMs kept:     Yes (--keep flag)"
    else
        echo "SRPMs removed:  Yes (successful builds only)"
    fi
    echo "=================================================="

    # Exit with error if any builds failed
    if [[ "$failed" -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
