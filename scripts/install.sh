#!/bin/bash
#
# iptables-docker Enhanced 安装脚本
#

set -e

SCRIPT_URL="https://raw.githubusercontent.com/snoopy7713/iptables-docker-enhanced.sh"
INSTALL_DIR="/usr/local/sbin"
SCRIPT_NAME="iptables-docker.sh"
SERVICE_NAME="iptables-docker.service"
CONFIG_DIR="/etc/iptables-docker"
IPTABLES_HOME=$(dirname "$(pwd)")


echo "================================================"
echo "  iptables-docker Enhanced 安装程序"
echo "================================================"
echo "IPTABLES_HOME: $IPTABLES_HOME"
echo ""

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo "错误: 必须以 root 用户运行此脚本"
    exit 1
fi

# 检查依赖
echo "[1/7] 检查依赖..."
for cmd in iptables iptables-save iptables-restore systemctl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "错误: 未找到必需的命令: $cmd"
        exit 1
    fi
done
echo "✓ 依赖检查通过"
echo ""

# 设置 iptables 为 legacy 模式
echo "[2/7] 配置 iptables..."
if ! iptables --version | grep -q legacy; then
	if command -v alternatives &> /dev/null; then
        # openEuler / RHEL 风格
        alternatives --set iptables /usr/sbin/iptables-legacy
        alternatives --set ip6tables /usr/sbin/ip6tables-legacy
	elif command -v update-alternatives &> /dev/null; then
        # Debian 风格
        update-alternatives --set iptables /usr/sbin/iptables-legacy
        update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
	else
        echo "警告: 无法自动切换到 iptables-legacy，你可能需要手动处理"
	fi
    echo "注意: 若 iptables 规则未生效，请重启系统或手动加载模块"
fi

echo "✓ iptables 配置完成"
echo ""

# 禁用其他防火墙服务
echo "[3/7] 禁用冲突的防火墙服务..."
for service in ufw firewalld; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        systemctl stop "$service"
        systemctl disable "$service"
        echo "✓ 已禁用 $service"
    fi
done
echo ""

# 安装脚本
echo "[4/7] 安装防火墙脚本..."
if [ -f "$IPTABLES_HOME/src/iptables-docker.sh" ]; then
    # 从当前目录安装
    cp "$IPTABLES_HOME/src/iptables-docker.sh" "$INSTALL_DIR/$SCRIPT_NAME"
	cp "$IPTABLES_HOME/src/awk.firewall" "$INSTALL_DIR/awk.firewall"
	chmod 700 "$INSTALL_DIR/$SCRIPT_NAME"
	chmod 600 "$INSTALL_DIR/awk.firewall"
    echo "✓ 已从当前目录安装脚本"
else
    echo "错误: 未找到 iptables-docker.sh 文件"
    echo "请将脚本文件放在当前目录,或直接编辑此安装脚本"
    exit 1
fi

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo ""

# 创建 systemd 服务
echo "[5/7] 创建 systemd 服务..."
cat > "/etc/systemd/system/$SERVICE_NAME" << EOF
[Unit]
Description=iptables Docker Enhanced Firewall
After=network.target docker.service
Wants=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$INSTALL_DIR/$SCRIPT_NAME start
ExecStop=$INSTALL_DIR/$SCRIPT_NAME stop
ExecReload=$INSTALL_DIR/$SCRIPT_NAME restart
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30
TimeoutStopSec=30

# 安全设置
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/etc/iptables-docker /var/lib/iptables-docker /var/log
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "✓ systemd 服务创建完成"
echo ""

# 初始化配置文件
echo "[6/7] 初始化配置..."
mkdir -p "$CONFIG_DIR"
mkdir -p "/var/lib/iptables-docker"

# 运行一次以生成默认配置文件
"$INSTALL_DIR/$SCRIPT_NAME" start
echo "✓ 配置初始化完成"
echo ""

# 启用并启动服务
echo "[7/7] 启用服务..."
systemctl enable "$SERVICE_NAME"
echo "✓ 服务已启用"
echo ""

echo "================================================"
echo "  安装完成!"
echo "================================================"
echo ""
echo "使用方法:"
echo "  1. 编辑配置文件: sudo $INSTALL_DIR/$SCRIPT_NAME edit"
echo "     或直接编辑: sudo vi $CONFIG_DIR/firewall-rules.conf"
echo ""
echo "  2. 重启防火墙使配置生效:"
echo "     sudo systemctl restart $SERVICE_NAME"
echo "     或: sudo $INSTALL_DIR/$SCRIPT_NAME restart"
echo ""
echo "  3. 查看防火墙状态:"
echo "     sudo systemctl status $SERVICE_NAME"
echo "     或: sudo $INSTALL_DIR/$SCRIPT_NAME status"
echo ""
echo "  4. 查看日志:"
echo "     sudo journalctl -u $SERVICE_NAME -f"
echo "     或: sudo tail -f /var/log/iptables-docker.log"
echo ""
echo "配置文件位置: $CONFIG_DIR/firewall-rules.conf"
echo ""
echo "重要提示:"
echo "  - 默认只开放 SSH(22) 端口"
echo "  - 请根据需要编辑配置文件开放其他端口"
echo "  - Docker 容器的网络功能已保留"
echo ""