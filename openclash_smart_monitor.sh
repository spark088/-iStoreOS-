#!/bin/sh
# OpenClash 智能监控与优化系统 (BusyBox 兼容版)
# 版本: 2.1
# 最后更新: 2025-08-11

# ===== 统一配置区 =====
OPENCLASH_SECRET="RjAJ3WCX"
OPENCLASH_HOST="127.0.0.1"
OPENCLASH_PORT="9090"

# 日志输出
log() {
    echo "[$(date '+%F %T')] $1"
}

# 获取当前节点
get_current_node() {
    curl -s -H "Authorization: Bearer $OPENCLASH_SECRET" \
         "http://$OPENCLASH_HOST:$OPENCLASH_PORT/configs" \
    | grep -E '"name"' \
    | head -n 1 \
    | sed 's/.*"name"[ ]*:[ ]*"//;s/".*//'
}

# 获取所有节点
get_all_nodes() {
    curl -s -H "Authorization: Bearer $OPENCLASH_SECRET" \
         "http://$OPENCLASH_HOST:$OPENCLASH_PORT/configs" \
    | grep -E '"name"' \
    | sed 's/.*"name"[ ]*:[ ]*"//;s/".*//'
}

# 切换节点
switch_node() {
    NODE_NAME="$1"
    curl -s -X PUT -H "Authorization: Bearer $OPENCLASH_SECRET" \
         -H "Content-Type: application/json" \
         -d "{\"name\":\"$NODE_NAME\"}" \
         "http://$OPENCLASH_HOST:$OPENCLASH_PORT/proxies/节点选择" >/dev/null
    log "已切换到节点: $NODE_NAME"
}

# ===== 主程序 =====
CURRENT_NODE=$(get_current_node)

if [ -z "$CURRENT_NODE" ]; then
    log "没有找到可用节点，保持当前节点"
    exit 0
fi

log "当前节点: $CURRENT_NODE"

# 这里可以加测速或检测逻辑
# 例如简单延迟检测
DELAY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 3 "https://www.google.com")
log "当前节点延迟: ${DELAY}s"
