#!/bin/sh
# OpenClash 智能监控与切换脚本 (GLaDOS节点优先版)
# 最后更新: 2025-08-11

# OpenClash API 配置
OPENCLASH_HOST="127.0.0.1"
OPENCLASH_PORT="9090"
OPENCLASH_SECRET="RjAJ3WCX"  # 你的 OpenClash 密钥

# 优先节点关键词（顺序匹配）
PRIORITY_KEYWORDS=("TW" "SG" "JP" "US")

# API 请求函数
clash_api() {
    curl -s -H "Authorization: Bearer $OPENCLASH_SECRET" \
         "http://$OPENCLASH_HOST:$OPENCLASH_PORT/$1"
}

# 获取当前节点
get_current_node() {
    clash_api "configs" | grep -oP '"Proxy":\s*"\K[^"]+'
}

# 获取所有节点
get_all_nodes() {
    clash_api "proxies" | grep -oP '"GLaDOS-[^"]+'
}

# 测试节点延迟
test_node() {
    clash_api "proxies/$1/delay?timeout=3000&url=http://www.gstatic.com/generate_204" \
    | grep -oP '"delay":\s*\K[0-9]+'
}

# 切换节点
switch_node() {
    clash_api "configs" \
        -X PATCH \
        -H "Content-Type: application/json" \
        -d "{\"Proxy\":\"$1\"}" >/dev/null
}

# 主程序
main() {
    CURRENT_NODE=$(get_current_node)
    echo "当前节点: $CURRENT_NODE"

    NODES=$(get_all_nodes)

    for KEY in "${PRIORITY_KEYWORDS[@]}"; do
        TARGET_NODE=$(echo "$NODES" | grep "$KEY" | head -n 1)
        if [ -n "$TARGET_NODE" ]; then
            DELAY=$(test_node "$TARGET_NODE")
            if [ -n "$DELAY" ] && [ "$DELAY" -lt 500 ]; then
                if [ "$TARGET_NODE" != "$CURRENT_NODE" ]; then
                    echo "$(date '+%F %T') 切换节点: $CURRENT_NODE → $TARGET_NODE (延迟 ${DELAY}ms)"
                    switch_node "$TARGET_NODE"
                else
                    echo "已在优先节点 $CURRENT_NODE，无需切换"
                fi
                exit 0
            fi
        fi
    done

    echo "没有找到可用节点，保持当前节点 $CURRENT_NODE"
}

main
