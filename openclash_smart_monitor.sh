#!/bin/sh
# OpenClash 智能测速脚本（自动模式识别版）
# 作者: GPT定制版
# 日期: 2025-08-11

# ============ 配置区 ============
OPENCLASH_HOST="127.0.0.1"
OPENCLASH_PORT="9090"
OPENCLASH_SECRET="RjAJ3WCX"

# 优先节点匹配关键字（正则）
PRIORITY_NODES="台湾|TW|Taiwan|新加坡|SG|Singapore|香港|HK|Hong"

# API URL 生成
api_get() {
    curl -s -m 3 -H "Authorization: Bearer $OPENCLASH_SECRET" \
         "http://$OPENCLASH_HOST:$OPENCLASH_PORT$1"
}

api_put() {
    curl -s -m 3 -X PUT -H "Authorization: Bearer $OPENCLASH_SECRET" \
         -H "Content-Type: application/json" \
         -d "$2" "http://$OPENCLASH_HOST:$OPENCLASH_PORT$1"
}

# 检测当前 OpenClash 模式
detect_mode() {
    MODE=$(api_get "/configs" | grep -o '"mode":"[^"]*' | cut -d'"' -f4)
    if [ -z "$MODE" ]; then
        echo "[错误] 无法获取 OpenClash 模式，默认使用 GLOBAL"
        MODE="GLOBAL"
    fi
    echo "[信息] 检测到 OpenClash 模式: $MODE"
}

# 获取优先节点列表
get_priority_nodes() {
    api_get "/proxies/$MODE" | grep -E "$PRIORITY_NODES" | awk -F '"' '{print $4}'
}

# 节点测速
test_node() {
    NODE=$1
    DELAY=$(api_get "/proxies/$NODE/delay?timeout=5000&url=https://www.google.com/generate_204" \
            | grep -o '"delay":[0-9]*' | cut -d':' -f2)
    [ -z "$DELAY" ] && DELAY=0
    echo "$NODE:$DELAY"
}

# 主循环
main_loop() {
    while true; do
        PRIORITY_LIST=$(get_priority_nodes)

        if [ -z "$PRIORITY_LIST" ]; then
            echo "[警告] 未找到优先节点，20 秒后重试..."
            sleep 20
            continue
        fi

        ONLINE_COUNT=0
        for NODE in $PRIORITY_LIST; do
            RESULT=$(test_node "$NODE")
            DELAY=$(echo "$RESULT" | cut -d':' -f2)

            if [ "$DELAY" -gt 0 ]; then
                echo "[在线] $NODE 延迟 ${DELAY}ms"
                ONLINE_COUNT=$((ONLINE_COUNT+1))
            else
                echo "[离线] $NODE，10 小时后重试"
                sleep 2
                # 延迟到10小时后再测（后台执行）
                (sleep 36000 && test_node "$NODE" > /dev/null) &
            fi
        done

        if [ "$ONLINE_COUNT" -eq 0 ]; then
            echo "[警告] 所有优先节点掉线，20 秒后重试..."
            sleep 20
        else
            echo "[信息] 测速完成，5 分钟后再次检测"
            sleep 300
        fi
    done
}

# 入口
detect_mode
main_loop
