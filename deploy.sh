#!/bin/sh
set -e

echo "[1/6] 安装轻量 Web 服务 uhttpd..."
opkg update
opkg install uhttpd

echo "[2/6] 创建监控页面目录..."
mkdir -p /www/oc_monitor

echo "[3/6] 下载前端页面文件..."
cat > /www/oc_monitor/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>OpenClash 监控面板</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
h2 { text-align: center; }
canvas { background: white; padding: 10px; border-radius: 10px; }
</style>
</head>
<body>
<h2>OpenClash 实时监控</h2>
<canvas id="speedChart" height="100"></canvas>
<script>
async function fetchData() {
    try {
        const res = await fetch('/tmp/openclash_status.json');
        const data = await res.json();
        updateChart(data);
    } catch (e) {
        console.error("获取数据失败", e);
    }
}
let chart;
function updateChart(data) {
    if (!chart) {
        chart = new Chart(document.getElementById('speedChart').getContext('2d'), {
            type: 'line',
            data: { labels: [], datasets: [{ label: '延迟(ms)', data: [], borderColor: 'blue', fill: false }] },
            options: { responsive: true, scales: { x: { display: false }, y: { beginAtZero: true } } }
        });
    }
    chart.data.labels.push("");
    chart.data.datasets[0].data.push(data.latency || 0);
    if (chart.data.labels.length > 50) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.update();
}
setInterval(fetchData, 3000);
</script>
</body>
</html>
EOF

echo "[4/6] 修改监控脚本输出 JSON 数据..."
MONITOR_SCRIPT="/usr/bin/openclash_smart_monitor"
if ! grep -q "openclash_status.json" "$MONITOR_SCRIPT"; then
    echo "在 $MONITOR_SCRIPT 中添加 JSON 输出逻辑..."
    cat >> "$MONITOR_SCRIPT" <<'ADDJSON'

# 输出状态到 JSON 文件
echo "{ \"latency\": \"$PING_DELAY\" }" > /tmp/openclash_status.json
ADDJSON
fi

echo "[5/6] 启动 uhttpd..."
/etc/init.d/uhttpd enable
/etc/init.d/uhttpd start

echo "[6/6] 部署完成！"
IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
echo "现在可以访问: http://$IP:8080/oc_monitor"
