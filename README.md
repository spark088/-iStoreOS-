# iStoreOS OpenClash 智能监控

自动测速 + 节点切换 + 延迟监控的轻量化脚本，适配 iStoreOS / OpenWrt / R4S。

## 功能
- 每 6 小时测速一次
- 自动切换到最优节点（可扩展）
- 日志保存到 `/etc/openclash/logs`

## 安装
```bash
opkg update && opkg install jq bc curl wget
mkdir -p /etc/openclash/logs

wget -O /usr/bin/openclash_smart_monitor.sh https://raw.githubusercontent.com/spark088/-iStoreOS-/main/openclash_smart_monitor.sh
chmod +x /usr/bin/openclash_smart_monitor.sh

wget -O /etc/init.d/openclash-monitor https://raw.githubusercontent.com/spark088/-iStoreOS-/main/openclash-monitor
chmod +x /etc/init.d/openclash-monitor
/etc/init.d/openclash-monitor enable
/etc/init.d/openclash-monitor start

wget -O /usr/bin/oclash-logs https://raw.githubusercontent.com/spark088/-iStoreOS-/main/oclash-logs
chmod +x /usr/bin/oclash-logs

wget -O /usr/bin/oclash-usage https://raw.githubusercontent.com/spark088/-iStoreOS-/main/oclash-usage
chmod +x /usr/bin/oclash-usage
