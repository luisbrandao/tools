#!/usr/bin/env bash
# =============================================================================
# kubeMEMextract.sh — Kubernetes Resource Audit Tool
# =============================================================================
#
# PURPOSE:
#   Audits CPU and memory resource allocation across a Kubernetes cluster.
#   Identifies over-provisioned nodes, namespaces with excessive requests,
#   and pods that request more resources than they actually consume.
#
# PROBLEMS THIS HELPS IDENTIFY:
#   - Nodes with high CPU/memory requests but low actual usage (over-provisioning)
#   - Namespaces requesting disproportionate cluster resources
#   - Pods with inflated resource requests vs actual consumption
#   - Clusters approaching capacity limits
#
# REQUIREMENTS:
#   - kubectl configured with access to the target cluster
#   - jq (for JSON parsing)
#   - Optional: metrics-server deployed in the cluster (for --usage flag)
#
# USAGE:
#   ./kubeMEMextract.sh [OPTIONS]
#
# OPTIONS:
#   -n, --namespace NS      Filter by namespace (default: all namespaces)
#   -t, --top N             Show top N resource-consuming pods (default: 10)
#   -u, --usage             Compare requests vs actual usage (requires metrics-server)
#   -o, --output FORMAT     Output format: table, csv, json (default: table)
#   -k, --kubeconfig PATH   Path to kubeconfig file (default: KUBECONFIG or ~/.kube/config)
#   -h, --help              Show this help message
#
# EXAMPLES:
#   # Full cluster audit with default settings
#   ./kubeMEMextract.sh
#
#   # Audit specific namespace with actual usage comparison
#   ./kubeMEMextract.sh --namespace production --usage
#
#   # Export top 20 pods to CSV
#   ./kubeMEMextract.sh --top 20 --output csv > audit.csv
#
#   # JSON output for piping to other tools
#   ./kubeMEMextract.sh --output json | jq '.nodes[] | select(.cpuRequestPct > 80)'
#
# EXIT CODES:
#   0 — Success
#   1 — General error (missing dependencies, kubectl failure)
#   2 — Usage error (invalid arguments)
#
# =============================================================================

set -euo pipefail

# --- Color output (disabled when piped or in CSV/JSON mode) ---
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_GREEN='\033[0;32m'
COLOR_BOLD='\033[1m'
USE_COLOR=true

# --- Defaults ---
NAMESPACE=""
TOP_N=10
SHOW_USAGE=false
OUTPUT_FORMAT="table"
KUBECONFIG_PATH=""

# =============================================================================
# Functions
# =============================================================================

usage() {
    sed -n 's/^#   //p; /^# USAGE:/,/^# EXIT CODES:/{ /^# PURPOSE:/d; /^# PROBLEMS/d; /^# REQUIREMENTS/d; /^# EXAMPLES/d; /^# OPTIONS:/d; /^# EXIT CODES:/d; p }' "$0" | head -20
    echo ""
    echo "OPTIONS:"
    echo "  -n, --namespace NS      Filter by namespace (default: all)"
    echo "  -t, --top N             Show top N resource-consuming pods (default: 10)"
    echo "  -u, --usage             Compare requests vs actual usage (requires metrics-server)"
    echo "  -o, --output FORMAT     Output format: table, csv, json (default: table)"
    echo "  -k, --kubeconfig PATH   Path to kubeconfig file"
    echo "  -h, --help              Show this help message"
}

die() {
    echo -e "${COLOR_RED}ERROR: $1${COLOR_RESET}" >&2
    exit 1
}

warn() {
    echo -e "${COLOR_YELLOW}WARNING: $1${COLOR_RESET}" >&2
}

info() {
    if [[ "$USE_COLOR" == true ]]; then
        echo -e "${COLOR_BOLD}$1${COLOR_RESET}"
    else
        echo "$1"
    fi
}

# Check for required dependencies
check_deps() {
    local missing=()
    command -v kubectl &>/dev/null || missing+=("kubectl")
    command -v jq &>/dev/null || missing+=("jq")
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required dependencies: ${missing[*]}"
    fi
}

# Set kubectl context
setup_kubectl() {
    local KCMD="kubectl"
    if [[ -n "$KUBECONFIG_PATH" ]]; then
        export KUBECONFIG="$KUBECONFIG_PATH"
    fi
    echo "$KCMD"
}

# Get namespace filter for kubectl queries
ns_filter() {
    if [[ -n "$NAMESPACE" ]]; then
        echo "-n $NAMESPACE"
    else
        echo ""
    fi
}

# Colorize percentage values based on thresholds
color_pct() {
    local pct="$1"
    # Strip decimal for comparison
    local int_pct="${pct%.*}"
    if [[ "$USE_COLOR" != true ]]; then
        echo "$pct%"
        return
    fi
    if [[ "$int_pct" -ge 80 ]]; then
        echo -e "${COLOR_RED}${pct}%${COLOR_RESET}"
    elif [[ "$int_pct" -ge 60 ]]; then
        echo -e "${COLOR_YELLOW}${pct}%${COLOR_RESET}"
    else
        echo -e "${COLOR_GREEN}${pct}%${COLOR_RESET}"
    fi
}

# =============================================================================
# Node Allocation Report
# =============================================================================
report_nodes() {
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        report_nodes_json
        return
    fi

    info ""
    info "═══════════════════════════════════════════════════════════════"
    info "  NODE RESOURCE ALLOCATION"
    info "═══════════════════════════════════════════════════════════════"

    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "node,cpuRequestM,cpuLimitM,memRequestMi,memLimitMi,cpuRequestPct,cpuLimitPct,memRequestPct,memLimitPct"
    fi

    local total_cpu_req=0
    local total_mem_req=0
    local node_count=0

    # Get node allocation via JSON API (reliable parsing)
    while IFS= read -r line; do
        local node cpu_req_m cpu_lim_m mem_req_mi mem_lim_mi cpu_req_pct cpu_lim_pct mem_req_pct mem_lim_pct
        node=$(echo "$line" | jq -r '.name')
        cpu_req_m=$(echo "$line" | jq -r '.cpuRequestM // 0')
        cpu_lim_m=$(echo "$line" | jq -r '.cpuLimitM // 0')
        mem_req_mi=$(echo "$line" | jq -r '.memRequestMi // 0')
        mem_lim_mi=$(echo "$line" | jq -r '.memLimitMi // 0')
        cpu_req_pct=$(echo "$line" | jq -r '.cpuRequestPct // 0')
        cpu_lim_pct=$(echo "$line" | jq -r '.cpuLimitPct // 0')
        mem_req_pct=$(echo "$line" | jq -r '.memRequestPct // 0')
        mem_lim_pct=$(echo "$line" | jq -r '.memLimitPct // 0')

        total_cpu_req=$((total_cpu_req + cpu_req_pct))
        total_mem_req=$((total_mem_req + mem_req_pct))
        node_count=$((node_count + 1))

        if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
            echo "${node},${cpu_req_m},${cpu_lim_m},${mem_req_mi},${mem_lim_mi},${cpu_req_pct},${cpu_lim_pct},${mem_req_pct},${mem_lim_pct}"
        else
            printf "  %-25s CPU Req: %4s Lim: %4s  |  MEM Req: %6s Lim: %6s\n" \
                "$node" \
                "$(color_pct "$cpu_req_pct")" "$(color_pct "$cpu_lim_pct")" \
                "$(color_pct "$mem_req_pct")" "$(color_pct "$mem_lim_pct")"
        fi
    done < <(kubectl get nodes -o json | jq -c '.items[] | {
        name: .metadata.name,
        cpuRequestM: (.status.allocatable.cpu | tonumber) * 1000,
        cpuLimitM: 0,
        memRequestMi: ((.status.allocatable.memory | gsub("[[:alpha:]]"; "") | tonumber) / 1024 / 1024 | floor),
        memLimitMi: 0,
        cpuRequestPct: 0,
        cpuLimitPct: 0,
        memRequestPct: 0,
        memLimitPct: 0
    }')

    # Actually get allocated resources from pod specs
    # This is more accurate than parsing describe output
    local node_data
    node_data=$(kubectl get nodes -o json | jq -c '.items[].metadata.name')

    while IFS= read -r node; do
        [[ -z "$node" ]] && continue

        local alloc
        alloc=$(kubectl describe node "$node" 2>/dev/null | \
            sed -n '/Allocated resources:/,/Requests\|Limits/{ p }' | \
            grep -E '^\s+(CPU|Memory)' | head -2) || true

        if [[ -n "$alloc" ]]; then
            local cpu_line mem_line
            cpu_line=$(echo "$alloc" | grep "CPU" || echo "")
            mem_line=$(echo "$alloc" | grep "Memory" || echo "")

            if [[ -n "$cpu_line" && -n "$mem_line" ]]; then
                # Parse: "  CPU Requests  CPU Limits  Memory Requests  Memory Limits"
                #           350m (17%)    2 (100%)    489Mi (13%)       1Gi (25%)
                local cpu_req_pct cpu_lim_pct mem_req_pct mem_lim_pct
                cpu_req_pct=$(echo "$cpu_line" | grep -oP '\(\K[0-9]+(?=%)') || echo "0"
                cpu_lim_pct=$(echo "$cpu_line" | grep -oP '\(\K[0-9]+(?=%)' | tail -1) || echo "0"

                # Memory line has two percentages too
                local all_pcts
                all_pcts=$(echo "${cpu_line} ${mem_line}" | grep -oP '\(\K[0-9]+(?=%)')
                local p1 p2 p3 p4
                p1=$(echo "$all_pcts" | sed -n '1p')
                p2=$(echo "$all_pcts" | sed -n '2p')
                p3=$(echo "$all_pcts" | sed -n '3p')
                p4=$(echo "$all_pcts" | sed -n '4p')

                cpu_req_pct=${p1:-0}
                cpu_lim_pct=${p2:-0}
                mem_req_pct=${p3:-0}
                mem_lim_pct=${p4:-0}

                total_cpu_req=$((total_cpu_req + cpu_req_pct))
                total_mem_req=$((total_mem_req + mem_req_pct))
                node_count=$((node_count + 1))

                if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
                    echo "${node},${cpu_req_pct},${cpu_lim_pct},${mem_req_pct},${mem_lim_pct}"
                else
                    printf "  %-25s CPU Req: %4s Lim: %4s  |  MEM Req: %6s Lim: %6s\n" \
                        "$node" \
                        "$(color_pct "$cpu_req_pct")" "$(color_pct "$cpu_lim_pct")" \
                        "$(color_pct "$mem_req_pct")" "$(color_pct "$mem_lim_pct")"
                fi
            fi
        fi
    done <<< "$node_data"

    # Cluster averages
    if [[ $node_count -gt 0 ]]; then
        local avg_cpu=$((total_cpu_req / node_count))
        local avg_mem=$((total_mem_req / node_count))

        if [[ "$OUTPUT_FORMAT" != "csv" ]]; then
            info ""
            info "───────────────────────────────────────────────────────────────"
            printf "  %sCLUSTER AVERAGES%s\n" "$COLOR_BOLD" "$COLOR_RESET"
            printf "    CPU Request Average: %s\n" "$(color_pct "$avg_cpu")"
            printf "    MEM Request Average: %s\n" "$(color_pct "$avg_mem")"

            # Capacity warning
            if [[ $avg_cpu -ge 80 ]]; then
                echo -e "    ${COLOR_RED}⚠ CLUSTER AT RISK — CPU requests averaging above 80%${COLOR_RESET}"
            fi
            if [[ $avg_mem -ge 80 ]]; then
                echo -e "    ${COLOR_RED}⚠ CLUSTER AT RISK — Memory requests averaging above 80%${COLOR_RESET}"
            fi
        fi
    fi
}

# =============================================================================
# Namespace Resource Breakdown
# =============================================================================
report_namespaces() {
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        report_namespaces_json
        return
    fi

    info ""
    info "═══════════════════════════════════════════════════════════════"
    info "  NAMESPACE RESOURCE BREAKDOWN"
    info "═══════════════════════════════════════════════════════════════"

    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "namespace,cpuRequestsM,cpuLimitsM,memoryRequestsMi,memoryLimitsMi,podCount"
    fi

    local ns_filter_flag=""
    if [[ -n "$NAMESPACE" ]]; then
        ns_filter_flag="-n $NAMESPACE"
    fi

    # Get all namespaces (or filtered)
    local namespaces
    if [[ -n "$NAMESPACE" ]]; then
        namespaces="$NAMESPACE"
    else
        namespaces=$(kubectl get namespaces -o json | jq -r '.items[].metadata.name' | grep -v '^kube-system$' || true)
    fi

    local total_cpu_all=0
    local total_mem_all=0

    while IFS= read -r ns; do
        [[ -z "$ns" ]] && continue

        # Sum resource requests for all pods in this namespace
        local result
        result=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | \
            awk '{print $1}' | while read -r pod; do
                kubectl get pod "$pod" -n "$ns" -o json 2>/dev/null | jq -r '
                    [.spec.containers[]?.resources.requests.cpu // 0,
                     .spec.containers[]?.resources.limits.cpu // 0,
                     .spec.containers[]?.resources.requests.memory // 0,
                     .spec.containers[]?.resources.limits.memory // 0] | @tsv
                ' 2>/dev/null || echo "0	0	0	0"
            done | awk '{
                cpu_req += $1; cpu_lim += $2; mem_req += $3; mem_lim += $4
            } END {
                printf "%.0f\t%.0f\t%.0f\t%.0f", cpu_req, cpu_lim, mem_req, mem_lim
            }') || result="0	0	0	0"

        local pod_count
        pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l) || echo "0"

        local cpu_req cpu_lim mem_req mem_lim
        IFS=$'\t' read -r cpu_req cpu_lim mem_req mem_lim <<< "$result"

        if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
            echo "${ns},${cpu_req},${cpu_lim},${mem_req},${mem_lim},${pod_count}"
        else
            printf "  %-25s Pods: %3s  CPU Req: %8s Lim: %8s  |  MEM Req: %10s Lim: %10s\n" \
                "$ns" "$pod_count" "$cpu_req" "$cpu_lim" "$mem_req" "$mem_lim"
        fi
    done <<< "$namespaces"
}

# =============================================================================
# Top Pods by Resource Requests
# =============================================================================
report_top_pods() {
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        report_top_pods_json
        return
    fi

    info ""
    info "═══════════════════════════════════════════════════════════════"
    info "  TOP $TOP_N PODS BY CPU REQUEST (Potential Over-Provisioning)"
    info "═══════════════════════════════════════════════════════════════"

    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "namespace,pod,cpuRequestsM,memoryRequestsMi"
    fi

    local ns_flag=""
    if [[ -n "$NAMESPACE" ]]; then
        ns_flag="-n $NAMESPACE"
    fi

    # Collect all pods with their CPU requests, sort descending
    kubectl get pods $ns_flag --all-namespaces 2>/dev/null | tail -n +2 | \
    while IFS= read -r line; do
        local ns pod
        ns=$(echo "$line" | awk '{print $1}')
        pod=$(echo "$line" | awk '{print $2}')

        local cpu_req_m
        cpu_req_m=$(kubectl get pod "$pod" -n "$ns" -o json 2>/dev/null | jq '
            [.spec.containers[]?.resources.requests.cpu // "0"] |
            map(gsub("[[:alpha:]]"; "") | tonumber * (if test("m$") then 1 elif test("e-") then pow(10; .) else 1000 end)) |
            add // 0
        ' 2>/dev/null || echo "0")

        local mem_req_mi
        mem_req_mi=$(kubectl get pod "$pod" -n "$ns" -o json 2>/dev/null | jq '
            [.spec.containers[]?.resources.requests.memory // "0"] |
            map(gsub("[[:alpha:]]"; "") | tonumber) |
            add // 0
        ' 2>/dev/null || echo "0")

        echo "${cpu_req_m}	${ns}	${pod}	${mem_req_mi}"
    done | sort -rn | head -n "$TOP_N" | while IFS=$'\t' read -r cpu ns pod mem; do
        if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
            echo "${ns},${pod},${cpu},${mem}"
        else
            printf "  %-25s %-30s CPU: %8s m  MEM: %10s Mi\n" \
                "$ns" "$pod" "$cpu" "$mem"
        fi
    done
}

# =============================================================================
# Actual Usage vs Requests (requires metrics-server)
# =============================================================================
report_usage() {
    # Check if metrics-server is available
    if ! kubectl top nodes &>/dev/null 2>&1; then
        warn "metrics-server not available — skipping usage comparison"
        return
    fi

    info ""
    info "═══════════════════════════════════════════════════════════════"
    info "  ACTUAL USAGE vs REQUESTED (Efficiency Analysis)"
    info "═══════════════════════════════════════════════════════════════"
    info "  Pods where actual usage is much lower than requested = wasted capacity"

    if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
        echo "namespace,pod,cpuRequestedM,cpuUsedM,cpuEfficiencyPct,memRequestedMi,memUsedMi,memEfficiencyPct"
    fi

    local ns_flag=""
    if [[ -n "$NAMESPACE" ]]; then
        ns_flag="-n $NAMESPACE"
    fi

    # Get pods and compare requests vs actual usage
    kubectl get pods $ns_flag --all-namespaces 2>/dev/null | tail -n +2 | \
    while IFS= read -r line; do
        local ns pod
        ns=$(echo "$line" | awk '{print $1}')
        pod=$(echo "$line" | awk '{print $2}')

        # Skip pods not in Running state
        local status
        status=$(echo "$line" | awk '{print $3}')
        [[ "$status" != "Running" ]] && continue

        # Get requests from pod spec
        local cpu_req_m mem_req_mi
        read -r cpu_req_m mem_req_mi < <(kubectl get pod "$pod" -n "$ns" -o json 2>/dev/null | jq -r '
            (
                ([.spec.containers[]?.resources.requests.cpu // "0"] |
                 map(gsub("m$"; "") | tonumber) | add // 0),
                ([.spec.containers[]?.resources.requests.memory // "0"] |
                 map(gsub("[[:alpha:]]"; "") | tonumber) | add // 0)
            ) | @tsv
        ' 2>/dev/null || echo "0	0")

        # Get actual usage from metrics-server
        local cpu_use_m mem_use_mi
        read -r cpu_use_m mem_use_mi < <(kubectl top pod "$pod" -n "$ns" --no-headers 2>/dev/null | \
            awk '{gsub("m","",$2); gsub("Mi","",$3); print $2, $3}' || echo "0 0")

        cpu_use_m=${cpu_use_m:-0}
        mem_use_mi=${mem_use_mi:-0}

        # Calculate efficiency (usage / request * 100)
        local cpu_eff=0 mem_eff=0
        if [[ "$cpu_req_m" -gt 0 ]]; then
            cpu_eff=$((cpu_use_m * 100 / cpu_req_m))
        fi
        if [[ "$mem_req_mi" -gt 0 ]]; then
            mem_eff=$((mem_use_mi * 100 / mem_req_mi))
        fi

        # Only show pods with low efficiency (< 50% of requested resources)
        if [[ $cpu_eff -lt 50 || $mem_eff -lt 50 ]]; then
            if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
                echo "${ns},${pod},${cpu_req_m},${cpu_use_m},${cpu_eff},${mem_req_mi},${mem_use_mi},${mem_eff}"
            else
                local cpu_flag="" mem_flag=""
                [[ $cpu_eff -lt 20 ]] && cpu_flag="${COLOR_RED} ← WASTED${COLOR_RESET}"
                [[ $cpu_eff -ge 20 && $cpu_eff -lt 50 ]] && cpu_flag="${COLOR_YELLOW} ← over-provisioned${COLOR_RESET}"
                [[ $mem_eff -lt 20 ]] && mem_flag="${COLOR_RED} ← WASTED${COLOR_RESET}"
                [[ $mem_eff -ge 20 && $mem_eff -lt 50 ]] && mem_flag="${COLOR_YELLOW} ← over-provisioned${COLOR_RESET}"

                printf "  %-15s %-25s CPU: %3d%% (%4sm/%4sm)%s  MEM: %3d%% (%6smi/%6smi)%s\n" \
                    "$ns" "$pod" \
                    "$cpu_eff" "$cpu_use_m" "$cpu_req_m" "$cpu_flag" \
                    "$mem_eff" "$mem_use_mi" "$mem_req_mi" "$mem_flag"
            fi
        fi
    done
}

# =============================================================================
# JSON Output (for programmatic consumption)
# =============================================================================
report_nodes_json() {
    kubectl get nodes -o json | jq '{
        cluster: .metadata.name,
        nodeCount: (.items | length),
        nodes: [.items[] | {
            name: .metadata.name,
            allocatable: .status.allocatable,
            capacity: .status.capacity,
            conditions: .status.conditions
        }]
    }'
}

report_namespaces_json() {
    local ns_list
    if [[ -n "$NAMESPACE" ]]; then
        ns_list="$NAMESPACE"
    else
        ns_list=$(kubectl get namespaces -o json | jq -r '.items[].metadata.name')
    fi

    echo "{"
    local first=true
    while IFS= read -r ns; do
        [[ -z "$ns" ]] && continue
        $first || echo ","
        first=false

        local pod_count cpu_req mem_req
        pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
        # Simplified: just output namespace and pod count for JSON mode
        printf '  "%s": {"podCount": %d}' "$ns" "$pod_count"
    done <<< "$ns_list"
    echo ""
    echo "}"
}

report_top_pods_json() {
    local ns_flag=""
    if [[ -n "$NAMESPACE" ]]; then
        ns_flag="-n $NAMESPACE"
    fi

    kubectl get pods $ns_flag --all-namespaces -o json 2>/dev/null | jq --arg top "$TOP_N" '
        .items | map({
            namespace: .metadata.namespace,
            name: .metadata.name,
            cpuRequest: ([.spec.containers[]?.resources.requests.cpu // "0"] | add),
            memoryRequest: ([.spec.containers[]?.resources.requests.memory // "0"] | add)
        }) | sort_by(-.cpuRequest) | .[:($top | tonumber)]
    '
}

# =============================================================================
# Main
# =============================================================================
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -t|--top)
                TOP_N="$2"
                shift 2
                ;;
            -u|--usage)
                SHOW_USAGE=true
                shift
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -k|--kubeconfig)
                KUBECONFIG_PATH="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done

    # Validate output format
    case "$OUTPUT_FORMAT" in
        table|csv|json) ;;
        *) die "Invalid output format: $OUTPUT_FORMAT (use: table, csv, json)" ;;
    esac

    # Disable color when not outputting to terminal or using non-table format
    if [[ ! -t 1 ]] || [[ "$OUTPUT_FORMAT" != "table" ]]; then
        USE_COLOR=false
    fi

    check_deps

    local start_time
    start_time=$(date +%s)

    info "╔═══════════════════════════════════════════════════════════════╗"
    info "║           KUBERNETES RESOURCE AUDIT REPORT                   ║"
    info "╚═══════════════════════════════════════════════════════════════╝"

    if [[ -n "$NAMESPACE" ]]; then
        echo "  Namespace: $NAMESPACE"
    else
        echo "  Scope: All namespaces"
    fi
    echo "  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

    # Run reports
    report_nodes
    report_namespaces
    report_top_pods

    if [[ "$SHOW_USAGE" == true ]]; then
        report_usage
    fi

    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))

    if [[ "$OUTPUT_FORMAT" == "table" ]]; then
        info ""
        info "───────────────────────────────────────────────────────────────"
        echo "  Report generated in ${elapsed}s"
    fi
}

main "$@"
