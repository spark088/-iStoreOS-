#!/bin/sh
# OpenClash 智能监控与优化系统 (iStoreOS 定制版)
# 版本: 2.3
# 最后更新: 2025-08-11

# ===== 基础配置 =====
OPENCLASH_SECRET=$(uci get openclash.config.api_secret 2>/dev/null)
OPENCLASH_HOST="127.0.0.1"
OPENCLASH_PORT="9090"
TG_BOT_TOKEN="替换为你的TG机器人Token"
TG_CHAT_ID="替换为你的TG聊天ID"
NET_CHECK_URL="http://www.gstatic.cn/generate_204"
MAX_LOG_DAYS=30

# ===== 流量控制配置 =====
NET_CHECK_INTERVAL=180
NET_FAIL_THRESHOLD=2
NODE_OPTIMIZE_INTERVAL=21600
SPEED_TEST_FILE="http://speedtest-sgp1.digitalocean.com/100kb.test"
MAX_SPEED_TEST_NODES=3
PING_THRESHOLD=500
PRIORITY_REGIONS="台湾 日本 新加坡"
SPEED_TEST_ENABLED=1
SPEED_TEST_THRESHOLD=50

# ===== 全局变量 =====
FAIL_COUNT=0
LAST_OPTIMIZE_TIME=$(date +%s)
LOG_FILE="/etc/openclash/logs/openclash_monitor.log"
LAST_NODE_FILE="/var/run/openclash_last_node"
CURRENT_NODE=""
MONTHLY_USAGE=0
USAGE_FILE="/var/run/openclash_usage"

# ===== 初始化 =====
mkdir -p /etc/openclash/logs
mkdir -p /var/run
touch "$LOG_FILE"
[ -f "$USAGE_FILE" ] && MONTHLY_USAGE=$(cat "$USAGE_FILE") || echo "0" > "$USAGE_FILE"

log() {
    local MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$MSG" | tee -a "$LOG_FILE"
}

track_usage() {
    local size=$1
    MONTHLY_USAGE=$((MONTHLY_USAGE + size))
    echo "$MONTHLY_USAGE" > "$USAGE_FILE"
}

send_tg() {
    local TEXT="$1"
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
         -d chat_id="${TG_CHAT_ID}" \
         -d text="${TEXT}" >/dev/null 2>&1
}

check_network() {
    if curl -s --max-time 10 "${NET_CHECK_URL}" >/dev/null; then
        track_usage 1
        return 0
    else
        track_usage 1
        return 1
    fi
}

get_current_node() {
    curl -s -H "Authorization: Bearer $OPENCLASH_SECRET" \
        "http://$OPENCLASH_HOST:$OPENCLASH_PORT/proxies/GLOBAL" | jq -r '.now'
}

get_priority_nodes() {
    curl -s -H "Authorization: Bearer $OPENCLASH_SECRET" \
        "http://$OPENCLASH_HOST:$OPENCLASH_PORT/proxies" | \
        jq -r '.proxies | to_entries[] | select(.value.type == "Shadowsocks" or .value.type == "VMess") | .key' | \
        grep -E "$(echo $PRIORITY_REGIONS | sed 's/ /|/g')" | head -n 10
}

test_node_delay() {
    local NODE="$1"
    local response=$(curl -s -H "Authorization: Bearer $OPENCLASH_SECRET" \
        "http://$OPENCLASH_HOST:$OPENCLASH_PORT/proxies/$NODE/delay?timeout=3000&url=$NET_CHECK_URL")
    echo "$response" | jq -r '.delay // 9999'
}

test_node_speed() {
    local NODE="$1"
    local speed=$(curl -x "http://$OPENCLASH_HOST:7890" -o /dev/null -s \
         -w "%{speed_download}" --max-time 10 "$SPEED_TEST_FILE" 2>/dev/null)
    echo "$speed" | awk '{printf "%.0f", $1/1024}'
}

switch_node() {
    local NODE="$1"
    local REASON="$2"
    if [ -n "$CURRENT_NODE" ]; then
        echo "$CURRENT_NODE" > "$LAST_NODE_FILE"
    fi
    local status=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
        -H "Authorization: Bearer $OPENCLASH_SECRET" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$NODE\"}" \
        "http://$OPENCLASH_HOST:$OPENCLASH_PORT/proxies/GLOBAL")
    if [ "$status" -eq 200 ]; then
        log "✅ 切换到节点: $NODE (原因: $REASON)"
        send_tg "🔄 OpenClash 切换到节点: $NODE\n原因: $REASON"
        CURRENT_NODE="$NODE"
        return 0
    else
        log "❌ 节点切换失败: $NODE"
        send_tg "⚠️ OpenClash 节点切换失败: $NODE"
        return 1
    fi
}

rollback_node() {
    if [ -f "$LAST_NODE_FILE" ]; then
        local OLD_NODE=$(cat "$LAST_NODE_FILE")
        if [ -n "$OLD_NODE" ]; then
            switch_node "$OLD_NODE" "新节点不可用"
        else
            send_tg "⚠️ 回滚节点文件为空"
        fi
    else
        send_tg "⚠️ 无可回滚节点"
    fi
}

optimize_nodes() {
    log "===== 开始节点优化 ====="
    local BEST_NODE=""
    local BEST_SCORE=0
    local nodes=$(get_priority_nodes)
    if [ -z "$nodes" ]; then
        send_tg "⚠️ 未获取到任何节点"
        return
    fi
    local tested_nodes=0
    for NODE in $nodes; do
        local DELAY=$(test_node_delay "$NODE")
        if [ "$DELAY" -le "$PING_THRESHOLD" ]; then
            local SPEED=0
            if [ "$SPEED_TEST_ENABLED" -eq 1 ] && [ $tested_nodes -lt $MAX_SPEED_TEST_NODES ]; then
                SPEED=$(test_node_speed "$NODE")
                tested_nodes=$((tested_nodes + 1))
                if [ "$SPEED" -lt "$SPEED_TEST_THRESHOLD" ]; then
                    continue
                fi
                SCORE=$(echo "$SPEED * (1 - $DELAY/$PING_THRESHOLD)" | bc -l)
                SCORE=${SCORE%.*}
            else
                SCORE=$((PING_THRESHOLD - DELAY))
            fi
            if [ $SCORE -gt $BEST_SCORE ]; then
                BEST_NODE="$NODE"
                BEST_SCORE=$SCORE
            fi
        fi
        sleep 1
    done
    if [ -n "$BEST_NODE" ] && [ "$BEST_NODE" != "$CURRENT_NODE" ]; then
        if switch_node "$BEST_NODE" "定期优化"; then
            sleep 10
            if ! check_network; then
                rollback_node
            fi
        fi
    fi
    log "===== 节点优化结束 ====="
}

log "===== OpenClash 智能监控启动 ====="
send_tg "🚀 OpenClash 智能监控已启动"

CURRENT_NODE=$(get_current_node)

while true; do
    if check_network; then
        if [ $FAIL_COUNT -gt 0 ]; then
            log "✅ 网络恢复"
            send_tg "✅ 网络恢复"
            FAIL_COUNT=0
        fi
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log "❌ 网络检测失败 ($FAIL_COUNT/$NET_FAIL_THRESHOLD)"
        if [ $FAIL_COUNT -ge $NET_FAIL_THRESHOLD ]; then
            send_tg "⚠️ 网络异常，触发节点优化"
            optimize_nodes
            FAIL_COUNT=0
        fi
    fi
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - LAST_OPTIMIZE_TIME)) -ge $NODE_OPTIMIZE_INTERVAL ]; then
        optimize_nodes
        LAST_OPTIMIZE_TIME=$CURRENT_TIME
    fi
    sleep $NET_CHECK_INTERVAL
done
