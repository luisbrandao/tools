#!/bin/bash
# ============================================
# check_server.sh — Monitoração de servidor via ntfy
# Roda em cada máquina via crontab de root.
# Deploy: /opt/scripts/check_server.sh (fonte: git/luis/tools/scripts/CheckNotify.sh)
#
# Uso:
#   check_server.sh            → verificação; alerta só se houver problema.
#                                Tem dedup: não repete o mesmo alerta a cada run,
#                                e avisa quando o problema é resolvido.
#   check_server.sh --report   → relatório completo (sempre envia)
#   check_server.sh --test     → envia notificação de teste
#
# Cron sugerido (em /etc/crontab):
#   */20 * * * * root /opt/scripts/check_server.sh
#   0 12 * * 0   root /opt/scripts/check_server.sh --report
# ============================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Preencher com o servidor/tópico ntfy e o token de acesso reais no deploy
NTFY_URL="https://ntfy.example.com/meu-topico"
NTFY_TOKEN="tk_XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
STATE_FILE="/var/tmp/check_server.state"

HOST=$(hostname -s)
DATE=$(date +"%d/%m/%Y %H:%M")
MODE="${1:-check}"

DISK_THRESHOLD=90    # % de uso de disco para alertar
RAM_THRESHOLD=90     # % de RAM em uso (desconta cache) para alertar
LOAD_MULTIPLIER=2    # alerta se load(5min) > nproc * multiplicador

# Serviços críticos (systemd) por máquina
case "$HOST" in
    gw)
        SERVICES=(sshd docker dnsmasq firewalld httpd gitea nfs-server
                  transmission-daemon smartd chronyd mdmonitor)
        ;;
    citrine)
        SERVICES=(sshd docker smartd node_exporter promtail chronyd)
        ;;
    luis)
        SERVICES=(sshd docker smartd netbird node_exporter promtail chronyd)
        ;;
    *)
        SERVICES=(sshd chronyd)
        ;;
esac

# === CHECAGENS (modo alerta) ===

get_disk_alerts() {
    local alerts=""
    while read -r _ size used _ pct mount; do
        local pct_num=${pct%\%}
        if [ "$pct_num" -gt "$DISK_THRESHOLD" ]; then
            alerts="${alerts}⚠️ Disco ${mount} em ${pct_num}% (${used}/${size})\n"
        fi
    done < <(df -hP | awk '$1 ~ /^\/dev\//')
    echo -en "$alerts"
}

get_ram_alert() {
    local total avail pct
    total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    pct=$(( (total - avail) * 100 / total ))
    if [ "$pct" -gt "$RAM_THRESHOLD" ]; then
        echo -en "⚠️ RAM em ${pct}% de uso\n"
    fi
}

get_load_alert() {
    local load5 cores
    load5=$(awk '{print $2}' /proc/loadavg)
    cores=$(nproc)
    if awk -v l="$load5" -v c="$cores" -v m="$LOAD_MULTIPLIER" 'BEGIN {exit !(l > c*m)}'; then
        echo -en "⚠️ CPU load(5min) ${load5} (${cores} núcleos)\n"
    fi
}

get_service_alerts() {
    local alerts="" svc
    for svc in "${SERVICES[@]}"; do
        # só checa serviços que existem nesta máquina
        systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q . || continue
        if systemctl is-enabled --quiet "$svc" 2>/dev/null && \
           ! systemctl is-active --quiet "$svc" 2>/dev/null; then
            alerts="${alerts}🔴 Serviço ${svc} PARADO\n"
        fi
    done
    echo -en "$alerts"
}

get_failed_units_alerts() {
    local alerts="" unit
    while read -r unit _; do
        [ -n "$unit" ] && alerts="${alerts}🔴 Unit ${unit} em estado failed\n"
    done < <(systemctl --failed --no-legend --plain 2>/dev/null)
    echo -en "$alerts"
}

get_raid_alerts() {
    [ -r /proc/mdstat ] || return 0
    local alerts="" md
    for md in $(grep -oE '^md[0-9]+' /proc/mdstat); do
        if grep -A2 "^${md} " /proc/mdstat | grep -qE '\[[U_]*_[U_]*\]'; then
            alerts="${alerts}💥 RAID ${md} DEGRADADO\n"
        fi
    done
    echo -en "$alerts"
}

get_docker_alerts() {
    command -v docker >/dev/null || return 0
    if ! docker info >/dev/null 2>&1; then
        echo -en "🔴 Docker daemon não responde\n"
        return
    fi
    local alerts="" line
    while read -r line; do
        [ -n "$line" ] && alerts="${alerts}🐳 Container ${line}\n"
    done < <({ docker ps --filter health=unhealthy --format '{{.Names}} ({{.Status}})'
               docker ps --filter status=restarting --format '{{.Names}} ({{.Status}})'; } | sort -u)
    echo -en "$alerts"
}

# === RELATÓRIO (modo --report) ===

get_disk_report() {
    df -hP | awk '$1 ~ /^\/dev\// {printf "  %s → %s/%s (%s)\\n", $6, $3, $2, $5}'
}

get_ram_report() {
    free -h | awk '/^Mem:/  {printf "  RAM: %s usada / %s total (livre real: %s)\\n", $3, $2, $7}
                   /^Swap:/ {if ($2 != "0B") printf "  Swap: %s / %s\\n", $3, $2}'
}

get_load_report() {
    awk -v c="$(nproc)" '{printf "  1min: %s | 5min: %s | 15min: %s (%s núcleos)\\n", $1, $2, $3, c}' /proc/loadavg
}

get_service_report() {
    local report="" svc
    for svc in "${SERVICES[@]}"; do
        systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q . || continue
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            report="${report}  ✅ ${svc}\n"
        elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            report="${report}  ❌ ${svc} (parado)\n"
        else
            report="${report}  ⬜ ${svc} (desativado)\n"
        fi
    done
    echo -en "$report"
}

get_raid_report() {
    [ -r /proc/mdstat ] || return 0
    grep -q '^md' /proc/mdstat || return 0
    local report=""
    report=$(awk '/^md/ {name=$1} /blocks/ {match($0, /\[[U_]+\]$/); printf "  %s %s\\n", name, substr($0, RSTART)}' /proc/mdstat)
    [ -n "$report" ] && echo -e "🧱 RAID:\n${report}"
}

get_docker_report() {
    command -v docker >/dev/null || return 0
    docker info >/dev/null 2>&1 || { echo -e "🐳 DOCKER: daemon não responde\n"; return; }
    local total problem
    total=$(docker ps -q | wc -l)
    problem=$({ docker ps --filter health=unhealthy --format '  ❌ {{.Names}} ({{.Status}})'
                docker ps --filter status=restarting --format '  ❌ {{.Names}} ({{.Status}})'; } | sort -u)
    echo -e "🐳 DOCKER: ${total} containers rodando"
    [ -n "$problem" ] && echo "$problem"
    echo ""
}

get_updates_report() {
    command -v dnf >/dev/null || return 0
    local n
    n=$(timeout 120 dnf -q check-update 2>/dev/null | grep -cE '^[[:alnum:]]')
    echo -e "📦 UPDATES: ${n} pacotes pendentes\n"
}

# === ENVIO ===

send_ntfy() {
    local title="$1" priority="$2" tags="$3" message="$4"
    if ! curl -fsS --max-time 15 \
         -H "Authorization: Bearer ${NTFY_TOKEN}" \
         -H "Title: ${title}" \
         -H "Priority: ${priority}" \
         -H "Tags: ${tags}" \
         -d "$(echo -e "${message}")" \
         "$NTFY_URL" >/dev/null; then
        logger -t check_server "ERRO: falha ao enviar notificação ntfy (${title})"
    fi
}

# === EXECUÇÃO ===

case "$MODE" in
--test)
    send_ntfy "Teste - ${HOST}" "default" "test_tube" "Notificação de teste — ${DATE}"
    echo "Notificação de teste enviada para ${NTFY_URL}"
    ;;

--report)
    MSG="📊 ${HOST} — ${DATE}\n"
    MSG+="━━━━━━━━━━━━━━━━━━━\n"
    MSG+="💾 DISCO:\n$(get_disk_report)\n"
    MSG+="🧠 MEMÓRIA:\n$(get_ram_report)\n"
    MSG+="⚡ CPU LOAD:\n$(get_load_report)\n"
    MSG+="⏱️ $(uptime -p)\n\n"
    RAID_R=$(get_raid_report);   [ -n "$RAID_R" ] && MSG+="${RAID_R}\n\n"
    DOCKER_R=$(get_docker_report); [ -n "$DOCKER_R" ] && MSG+="${DOCKER_R}\n\n"
    MSG+="🔧 SERVIÇOS:\n$(get_service_report)\n"
    MSG+="$(get_updates_report)"

    send_ntfy "Relatorio - ${HOST}" "default" "bar_chart" "$MSG"
    ;;

check|*)
    ALERTS=""
    ALERTS+="$(get_disk_alerts)"
    ALERTS+="$(get_ram_alert)"
    ALERTS+="$(get_load_alert)"
    ALERTS+="$(get_raid_alerts)"
    ALERTS+="$(get_service_alerts)"
    ALERTS+="$(get_failed_units_alerts)"
    ALERTS+="$(get_docker_alerts)"

    if [ -n "$ALERTS" ]; then
        # dedup: só reenvia se o conjunto de alertas mudou (ignora variação de números)
        KEY=$(echo "$ALERTS" | tr -d '0-9.,%' | md5sum | cut -d' ' -f1)
        LAST=$(cat "$STATE_FILE" 2>/dev/null)
        if [ "$KEY" != "$LAST" ]; then
            send_ntfy "ALERTA - ${HOST}" "high" "rotating_light" "🚨 ${HOST} — ${DATE}\n\n${ALERTS}"
            echo "$KEY" > "$STATE_FILE"
        fi
    elif [ -f "$STATE_FILE" ]; then
        send_ntfy "Resolvido - ${HOST}" "default" "white_check_mark" "✅ ${HOST} — ${DATE}\n\nTodos os problemas anteriores foram resolvidos."
        rm -f "$STATE_FILE"
    fi
    ;;
esac
