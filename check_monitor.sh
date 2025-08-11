#!/bin/sh
echo "=== 检查 OpenClash 智能监控进程 ==="
ps | grep openclash_smart_monitor | grep -v grep

echo ""
echo "=== 检查 Speedtest 相关进程 ==="
ps | grep speedtest | grep -v grep

echo ""
echo "=== 检查 JSON 数据文件 ==="
ls -lh /www/openclash/status.json 2>/dev/null
if [ -f /www/openclash/status.json ]; then
    echo "----- 文件内容预览 -----"
    head -n 10 /www/openclash/status.json
fi

echo ""
echo "=== 检查 Speedtest 可执行文件 ==="
which speedtest || which speedtest-cli || echo "未找到 speedtest 工具"

echo ""
echo "=== 测试运行 Speedtest ==="
if command -v speedtest >/dev/null 2>&1; then
    speedtest --version
    speedtest --accept-license --accept-gdpr -f json-pretty | head -n 10
elif command -v speedtest-cli >/dev/null 2>&1; then
    speedtest-cli --version
    speedtest-cli --json | head -n 10
else
    echo "⚠ 未安装 speedtest 或 speedtest-cli"
fi
