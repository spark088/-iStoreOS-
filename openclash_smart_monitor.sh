#!/bin/sh
# OpenClash 智能监控与测速脚本（改进版）
# 功能：
# 1. 自动识别 OpenClash 模式（GLOBAL / RULE）
# 2. 优先节点匹配：台湾、新加坡、香港
# 3. 节点离线重试策略：
#    - 单节点离线：10 小时后重试
#    - 全部节点离线：20 秒后重试

# ===== 配置 =====
OPENCLASH_HOST="127.0.0.1"
OPENCLASH_PORT="9090"
SECRET="你的密钥"  # 改成你的 API 密钥
PRIORITY_REGEX="台湾|TW|Taiwan|新加坡|SG|Singapore|香港|HK|Hong Kong"

API_URL="http://$OPENCLASH_HOST:$OPENCLASH_PORT"
AUTH_HEADER="Authorization: Bearer $SECRET"

# 检测 OpenClash 模式
detect_mode() {
    mode=$(curl -s -H "$AUTH_HEADER" "$API_URL/configs" | grep -oE '"mode":"[^"]+"' | cut -d'"' -f4 | tr 'A-Z' 'a-z')
    if [ "$mode" = "global" ]; then
        PROXY_PATH="/proxies/GLOBAL"
    elif [ "$mode" = "rule" ]; then
        PROXY_PATH="/proxies"
    else
        echo "[错误] 无法识别 OpenClash 模式，默认使用 RULE"
        PROXY_PATH="/proxies"
    fi
    echo "[信息] 检测到 OpenClash 模式: $mode"
}

# 获取所有节点
get_nodes() {
    curl -s -H "$AUTH_HEADER" "$API_URL$PROXY_PATH" | grep -oE '"name":"[^"]+"' | cut -d'"' -f4
}

# 筛选优先节点
get_priority_nodes() {
    get_nodes | grep -E "$PRIORITY_REGEX"
}

# 测试节点延迟
test_latency() {
    node="$1"
    curl -s -H "$AUTH_HEADER" -X PUT "$API_URL$PROXY_PATH/$node/delay" \
         -d '{"timeout": 3000, "url": "https://www.gstatic.com/generate_204"}' \
         | grep -oE '"delay":[0-9]+' | cut -d':' -f2
}

# 主循环
main_loop() {
    detect_mode
    while true; do
        priority_nodes=$(get_priority_nodes)

        if [ -z "$priority_nodes" ]; then
            echo "[警告] 未找到优先节点，20 秒后重试..."
            sleep 20
            continue
        fi

        all_offline=true
        for node in $priority_nodes; do
            latency=$(test_latency "$node")
            if [ -n "$latency" ] && [ "$latency" -gt 0 ]; then
                echo "[信息] 节点 $node 延迟: ${latency}ms"
                all_offline=false
            else
                echo "[警告] 节点 $node 离线，10 小时后重试"
                sleep 36000 &
            fi
        done

        if $all_offline; then
            echo "[警告] 所有优先节点掉线，20 秒后重试..."
            sleep 20
        else
            echo "[信息] 本轮检测完成，180 秒后再次检测"
            sleep 180
        fi
    done
}

main_loop
