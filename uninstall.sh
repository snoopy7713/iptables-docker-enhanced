#!/bin/bash
#
# iptables-docker Enhanced 卸载脚本
#

set -e

INSTALL_DIR="/usr/local/sbin"
SCRIPT_NAME="iptables-docker.sh"
SERVICE_NAME="iptables-docker.service"
CONFIG_DIR="/etc/iptables-docker"
DATA_DIR="/var/lib/iptables-docker"
LOG_FILE="/var/log/iptables-docker.log"

echo "================================================"
echo "  iptables-docker Enhanced 卸载程序"
echo "================================================"
echo ""

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 必须以 root 用户运行此脚本"
    exit 1
fi

# 询问是否删除配置文件
read -p "是否删除配置文件? (y/n): " DELETE_CONFIG
echo ""

echo "[1/5] 停止服务..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME"
    echo "✓ 服务已停止"
else
    echo "✓ 服务未运行"
fi
echo ""

echo "[2/5] 禁用服务..."
if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl disable "$SERVICE_NAME"
    echo "✓ 服务已禁用"
fi
echo ""

echo "[3/5] 删除服务文件..."
if [ -f "/etc/systemd/system/$SERVICE_NAME" ]; then
    rm -f "/etc/systemd/system/$SERVICE_NAME"
    systemctl daemon-reload
    echo "✓ 服务文件已删除"
fi
echo ""

echo "[4/5] 删除脚本文件..."
if [ -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    rm -f "$INSTALL_DIR/$SCRIPT_NAME"
    echo "✓ 脚本文件已删除"
fi
echo ""

echo "[5/5] 清理配置和数据..."
if [ "$DELETE_CONFIG" = "y" ] || [ "$DELETE_CONFIG" = "Y" ]; then
    [ -d "$CONFIG_DIR" ] && rm -rf "$CONFIG_DIR" && echo "✓ 配置目录已删除: $CONFIG_DIR"
    [ -d "$DATA_DIR" ] && rm -rf "$DATA_DIR" && echo "✓ 数据目录已删除: $DATA_DIR"
    [ -f "$LOG_FILE" ] && rm -f "$LOG_FILE" && echo "✓ 日志文件已删除: $LOG_FILE"
else
    echo "✓ 保留配置文件和数据"
    echo "  配置目录: $CONFIG_DIR"
    echo "  数据目录: $DATA_DIR"
    echo "  日志文件: $LOG_FILE"
fi
echo ""

echo "================================================"
echo "  卸载完成!"
echo "================================================"
echo ""
echo "注意事项:"
echo "  - iptables 规则已恢复为系统默认状态"
echo "  - Docker 容器的网络功能已保留"
echo "  - 如需重新启用系统防火墙,请手动操作"
echo ""