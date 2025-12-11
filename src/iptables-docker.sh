#!/bin/bash
#
# 增强版 iptables-docker 防火墙脚本
# 融合配置文件管理和完整安全防护功能
#

set -o errexit
set -o nounset
if [ "${TRACE-0}" -eq 1 ]; then set -o xtrace; fi

# 配置文件路径
CONFIG_DIR="/etc/iptables-docker"
RULES_CONFIG="${CONFIG_DIR}/firewall-rules.conf"
SECURITY_CONFIG="${CONFIG_DIR}/security.conf"
DOCKER_RULES="/var/lib/iptables-docker/docker.rules"
BACKUP_DIR="/var/lib/iptables-docker/backup"

# AWK 脚本路径（放在脚本同目录下）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWK_FIREWALL="$SCRIPT_DIR/awk.firewall"

# iptables 可执行文件
IPT=$(which iptables)
IPTS=$(which iptables-save)
IPTR=$(which iptables-restore)

# 日志文件
LOG_FILE="/var/log/iptables-docker.log"

# 获取默认网络接口
get_default_interface() {
    ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//" | head -1
}

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 创建配置目录和文件
init_config() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$DOCKER_RULES")"
    mkdir -p "$BACKUP_DIR"
    
    # 创建防火墙规则配置文件
    if [ ! -f "$RULES_CONFIG" ]; then
        log "创建默认防火墙规则配置文件: $RULES_CONFIG"
        cat > "$RULES_CONFIG" << 'EOF'
# iptables-docker 防火墙规则配置文件
# 
# 格式说明:
# 1. 以 # 开头的行是注释
# 2. 空行会被忽略
# 3. 每行一条规则,格式如下:
#
# 开放端口规则:
#   ALLOW_PORT <端口号> <协议> <源IP/CIDR> [描述]
#   例如: ALLOW_PORT 80 tcp 0.0.0.0/0 Web服务
#
# 允许源IP规则:
#   ALLOW_SOURCE <源IP/CIDR> [描述]
#   例如: ALLOW_SOURCE 192.168.1.0/24 内网访问
#
# 端口转发规则:
#   FORWARD_PORT <外部端口> <内部IP> <内部端口> <协议> [描述]
#   例如: FORWARD_PORT 8080 172.17.0.2 80 tcp 转发到容器
#

# ============================================
# SSH 访问配置
# ============================================
ALLOW_PORT 22 tcp 0.0.0.0/0 SSH远程访问

# ============================================
# Web 服务配置
# ============================================
# ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP服务
# ALLOW_PORT 443 tcp 0.0.0.0/0 HTTPS服务

# ============================================
# 其他服务配置
# ============================================
# ALLOW_PORT 3306 tcp 192.168.1.0/24 MySQL数据库(仅内网)
# ALLOW_PORT 6379 tcp 192.168.1.0/24 Redis(仅内网)

# ============================================
# 允许的源IP配置
# ============================================
# ALLOW_SOURCE 192.168.1.100 管理员机器
# ALLOW_SOURCE 10.0.0.0/8 内部网络

# ============================================
# Docker Swarm 配置 (如需要请取消注释)
# ============================================
# ALLOW_PORT 2377 tcp 192.168.1.0/24 Swarm管理端口
# ALLOW_PORT 7946 tcp 192.168.1.0/24 Swarm节点通信
# ALLOW_PORT 7946 udp 192.168.1.0/24 Swarm节点通信
# ALLOW_PORT 4789 udp 192.168.1.0/24 Swarm overlay网络

# ============================================
# 容器端口白名单配置（控制外部访问容器）
# ============================================
# 格式：ALLOW_CONTAINER_PORT <端口> <协议> <源IP> [描述]
# 说明：控制外部机器访问bridge模式容器的映射端口，容器间通信不受影响
# 注意：Host网络模式的容器请使用 ALLOW_PORT 配置
# 
# ALLOW_CONTAINER_PORT 3306 tcp 192.168.1.0/24 MySQL容器
# ALLOW_CONTAINER_PORT 6379 tcp 127.0.0.1 Redis容器(仅本机)
# ALLOW_CONTAINER_PORT 27017 tcp 10.0.0.0/8 MongoDB容器

EOF
    fi
    
    # 创建安全配置文件
    if [ ! -f "$SECURITY_CONFIG" ]; then
        log "创建默认安全配置文件: $SECURITY_CONFIG"
        cat > "$SECURITY_CONFIG" << 'EOF'
# iptables-docker 安全配置文件
# 
# 启用/禁用各种安全防护功能
# true = 启用, false = 禁用
#

# 反扫描保护 - 检测和阻止各种端口扫描
ENABLE_ANTI_SCAN=true

# 反IP欺骗保护 - 启用反向路径过滤
ENABLE_ANTI_SPOOF=true

# 反SYN Flood保护 - 启用SYN cookies
ENABLE_SYN_COOKIES=true

# 恶意数据包过滤 - 过滤分片包、广播包等
ENABLE_PACKET_FILTER=true

# 详细日志记录 - 记录被丢弃的数据包
ENABLE_DETAILED_LOGGING=true

# 日志记录频率限制 (每分钟最多记录几条)
LOG_LIMIT_RATE=2

# ICMP 支持 - 允许ping等ICMP包
ENABLE_ICMP=true

EOF
    fi
}

# 读取安全配置
load_security_config() {
    # 设置默认值
    ENABLE_ANTI_SCAN=true
    ENABLE_ANTI_SPOOF=true
    ENABLE_SYN_COOKIES=true
    ENABLE_PACKET_FILTER=true
    ENABLE_DETAILED_LOGGING=true
    LOG_LIMIT_RATE=2
    ENABLE_ICMP=true
    
    if [ -f "$SECURITY_CONFIG" ]; then
        # 读取配置文件
        while IFS='=' read -r key value; do
            # 跳过注释和空行
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${key// }" ]] && continue
            
            case "$key" in
                ENABLE_ANTI_SCAN) ENABLE_ANTI_SCAN="$value" ;;
                ENABLE_ANTI_SPOOF) ENABLE_ANTI_SPOOF="$value" ;;
                ENABLE_SYN_COOKIES) ENABLE_SYN_COOKIES="$value" ;;
                ENABLE_PACKET_FILTER) ENABLE_PACKET_FILTER="$value" ;;
                ENABLE_DETAILED_LOGGING) ENABLE_DETAILED_LOGGING="$value" ;;
                LOG_LIMIT_RATE) LOG_LIMIT_RATE="$value" ;;
                ENABLE_ICMP) ENABLE_ICMP="$value" ;;
            esac
        done < "$SECURITY_CONFIG"
        log "安全配置已加载"
    fi
}

# 读取并解析防火墙规则配置文件
parse_firewall_config() {
    if [ ! -f "$RULES_CONFIG" ]; then
        log "错误: 配置文件不存在: $RULES_CONFIG"
        return 1
    fi
    
    # 清空临时规则数组
    unset ALLOW_PORTS
    unset ALLOW_SOURCES
    unset FORWARD_PORTS
    declare -g -a ALLOW_PORTS=()
    declare -g -a ALLOW_SOURCES=()
    declare -g -a FORWARD_PORTS=()
    
    while IFS= read -r line || [ -n "$line" ]; do
        # 跳过注释和空行
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
         # 解析规则
        if [[ "$line" =~ ^ALLOW_PORT[[:space:]]+ ]]; then
            ALLOW_PORTS+=("$line")
        elif [[ "$line" =~ ^ALLOW_SOURCE[[:space:]]+ ]]; then
            ALLOW_SOURCES+=("$line")
        elif [[ "$line" =~ ^FORWARD_PORT[[:space:]]+ ]]; then
            FORWARD_PORTS+=("$line")
        elif [[ "$line" =~ ^ALLOW_CONTAINER_PORT[[:space:]]+ ]]; then
            ALLOW_CONTAINER_PORTS+=("$line")
        fi
    done < "$RULES_CONFIG"
    
     log "已加载 ${#ALLOW_PORTS[@]} 条端口规则, ${#ALLOW_SOURCES[@]} 条源IP规则, ${#FORWARD_PORTS[@]} 条转发规则, ${#ALLOW_CONTAINER_PORTS[@]} 条容器端口规则"
}

# 创建规则备份
create_backup() {
    local backup_file="$BACKUP_DIR/rules_$(date +%Y%m%d%H%M%S)"
    
    log "创建规则备份: $backup_file"
    touch "$backup_file"
    chmod 600 "$backup_file"
    $IPTS -c > "$backup_file"
    
    # 只保留最近10个备份
    ls -t "$BACKUP_DIR"/rules_* 2>/dev/null | tail -n +11 | xargs -r rm -f
}

# 保存 Docker 相关的 iptables 规则
preserve_docker_rules() {
    log "保存 Docker 相关规则..."
    
    # 检查 AWK 脚本是否存在
    if [ ! -f "$AWK_FIREWALL" ]; then
        log "错误: 找不到 awk.firewall 文件: $AWK_FIREWALL"
        log "尝试使用内置方法..."
        
        # 降级方案：使用内置 AWK（但不如外部文件完整）
        $IPTS | awk '
        BEGIN { 
            nat=0; filter=0; mangle=0; 
        }
        /^\*nat/ { nat=1; filter=0; mangle=0; print; next; }
        /^\*filter/ { nat=0; filter=1; mangle=0; print; next; }
        /^\*mangle/ { nat=0; filter=0; mangle=1; print; next; }
        
        # 打印链定义
        /^:/ {
            chain = $1;
            gsub(/:/, "", chain);
            if (nat==1 && (chain ~ /DOCKER|PREROUTING|POSTROUTING|OUTPUT/)) { print; next; }
            if (filter==1 && (chain ~ /DOCKER|FORWARD|INPUT|OUTPUT/)) { print; next; }
            if (chain ~ /INPUT|OUTPUT|FORWARD|PREROUTING|POSTROUTING/) { print; next; }
            next;
        }
        
        # NAT 表规则
        nat==1 && (/DOCKER/ || /-A PREROUTING.*DNAT/ || /-A POSTROUTING.*MASQUERADE/) { print; next; }
        
        # FILTER 表规则  
        filter==1 && (/DOCKER/ || /-A FORWARD.*docker/ || /-A FORWARD.*br-/ || /-A FORWARD.*veth/) { print; next; }
        
        # COMMIT
        /^COMMIT/ { print; next; }
        ' > "$DOCKER_RULES"
    else
        # 使用外部 AWK 文件（推荐）
        log "使用 awk.firewall 提取 Docker 规则..."
        awk -f "$AWK_FIREWALL" < <($IPTS) > "$DOCKER_RULES"
    fi
    
    # 验证生成的规则文件
    if [ -s "$DOCKER_RULES" ]; then
        log "Docker 规则已保存到 $DOCKER_RULES ($(wc -l < "$DOCKER_RULES") 行)"
    else
        log "警告: Docker 规则文件为空或未生成"
    fi
}

# 恢复 Docker 规则
restore_docker_rules() {
    if [ -f "$DOCKER_RULES" ]; then
		 if [ ! -f "$DOCKER_RULES" ]; then
			log "警告: Docker 规则文件不存在: $DOCKER_RULES"
			return 0
		fi
		
		if [ ! -s "$DOCKER_RULES" ]; then
			log "警告: Docker 规则文件为空，跳过恢复"
			return 0
		fi
	
        log "恢复 Docker 相关规则..."
		
		# 使用 iptables-restore 恢复规则
		# 使用 --noflush 选项避免清空已有规则
		if $IPTR --noflush < "$DOCKER_RULES" 2>&1 | tee -a "$LOG_FILE"; then
			log "Docker 规则恢复成功"
			
			# 验证恢复的链
			log "验证恢复的 Docker 链："
			for chain in DOCKER DOCKER-USER DOCKER-ISOLATION-STAGE-1 DOCKER-ISOLATION-STAGE-2 DOCKER-INGRESS; do
				if $IPT -t filter -L "$chain" -n >/dev/null 2>&1; then
					log "  ✓ $chain 链已恢复"
				fi
			done
		else
			log "警告: Docker 规则恢复时出现错误，但将继续执行"
		fi
	fi
}

# 跳过 Docker 接口的过滤
skip_docker_interfaces() {
    log "允许 Docker 相关网络接口流量..."
    
    # 获取所有网络接口
    local ifaces
    ifaces=$(ip -o link show | awk -F': ' '{print $2}')
    
    for iface in $ifaces; do
        # 处理 veth 接口
        if [[ "$iface" =~ ^veth ]]; then
            local vet_value="${iface%%@*}"
            $IPT -I INPUT -i "$vet_value" -j ACCEPT 2>/dev/null || true
            $IPT -I OUTPUT -o "$vet_value" -j ACCEPT 2>/dev/null || true
            $IPT -I FORWARD -i "$vet_value" -j ACCEPT 2>/dev/null || true
            $IPT -I FORWARD -o "$vet_value" -j ACCEPT 2>/dev/null || true
        fi
        
        # 处理 Docker bridge 接口
        if [[ "$iface" =~ ^br- ]] || [[ "$iface" =~ ^docker ]]; then
            $IPT -I INPUT -i "$iface" -j ACCEPT 2>/dev/null || true
            $IPT -I OUTPUT -o "$iface" -j ACCEPT 2>/dev/null || true
            $IPT -I FORWARD -i "$iface" -j ACCEPT 2>/dev/null || true
            $IPT -I FORWARD -o "$iface" -j ACCEPT 2>/dev/null || true
        fi
    done
}

# 设置安全防护功能
setup_security_features() {
    log "配置安全防护功能..."
    
    # 反IP欺骗保护
    if [ "$ENABLE_ANTI_SPOOF" = "true" ]; then
        log "启用反IP欺骗保护..."
        if [ -e /proc/sys/net/ipv4/conf/all/rp_filter ]; then
            for filter_file in /proc/sys/net/ipv4/conf/*/rp_filter; do
                echo 1 > "$filter_file" 2>/dev/null || true
            done
            log "反IP欺骗保护已启用"
        fi
    fi
    
    # 反SYN flood保护
    if [ "$ENABLE_SYN_COOKIES" = "true" ]; then
        log "启用SYN cookies..."
        if [ -e /proc/sys/net/ipv4/tcp_syncookies ]; then
            echo 1 > /proc/sys/net/ipv4/tcp_syncookies
            log "SYN cookies 已启用"
        fi
    fi
    
    # 反扫描保护
    if [ "$ENABLE_ANTI_SCAN" = "true" ]; then
        log "设置反扫描保护..."
        $IPT -N SCANS 2>/dev/null || $IPT -F SCANS
        $IPT -A SCANS -p tcp --tcp-flags FIN,URG,PSH FIN,URG,PSH -j DROP
        $IPT -A SCANS -p tcp --tcp-flags ALL ALL -j DROP
        $IPT -A SCANS -p tcp --tcp-flags ALL NONE -j DROP
        $IPT -A SCANS -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
        $IPT -A INPUT -j SCANS
        log "反扫描保护已启用"
    fi
    
    # 恶意数据包过滤
    if [ "$ENABLE_PACKET_FILTER" = "true" ]; then
        log "设置数据包过滤..."
        # 确保新的TCP连接都是SYN包
        $IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
        # 丢弃分片数据包
        $IPT -A INPUT -f -j DROP
        # 丢弃广播数据包
        $IPT -A INPUT -m pkttype --pkt-type broadcast -j DROP
        log "数据包过滤已启用"
    fi
    
    # 详细日志记录
    if [ "$ENABLE_DETAILED_LOGGING" = "true" ]; then
        log "设置详细日志记录..."
        $IPT -N LOGGING 2>/dev/null || $IPT -F LOGGING
        $IPT -A LOGGING -m limit --limit "${LOG_LIMIT_RATE}/min" -j LOG --log-prefix "IPTables-Dropped: " --log-level 4
        $IPT -A LOGGING -j DROP
        log "详细日志记录已启用 (频率限制: ${LOG_LIMIT_RATE}/min)"
    fi
}

# 启动防火墙
start_firewall() {
    log "启动 iptables-docker 防火墙..."
    
    # 初始化配置
    init_config
    
    # 加载配置
    load_security_config
    parse_firewall_config || return 1
    
    # 创建备份
    create_backup
    
    # 保存 Docker 规则
    preserve_docker_rules
    
    # 清空现有规则
    log "清空现有防火墙规则..."
    $IPT -F
    $IPT -X 2>/dev/null || true
    $IPT -Z
    $IPT -t nat -F
    $IPT -t nat -X 2>/dev/null || true
    $IPT -t mangle -F
    $IPT -t mangle -X 2>/dev/null || true
    
    # 恢复 Docker 规则
    restore_docker_rules
    
    # 跳过 Docker 接口过滤
    skip_docker_interfaces
    
    # 设置默认策略
    log "设置默认策略..."
    $IPT -P INPUT DROP
    $IPT -P FORWARD DROP
    $IPT -P OUTPUT ACCEPT
    
    # 允许本地回环
    $IPT -A INPUT -i lo -j ACCEPT
    $IPT -A OUTPUT -o lo -j ACCEPT
    
    # 设置安全防护功能
    setup_security_features
    
    # 允许已建立的连接
    $IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # 应用源IP白名单规则
    log "应用源IP白名单规则..."
    for rule in "${ALLOW_SOURCES[@]}"; do
        read -r cmd source_ip desc <<< "$rule"
        if [ -n "$source_ip" ]; then
            $IPT -A INPUT -s "$source_ip" -j ACCEPT
            log "已允许源IP: $source_ip ${desc:+($desc)}"
        fi
    done
    
    # 应用端口开放规则
    log "应用端口开放规则..."
    for rule in "${ALLOW_PORTS[@]}"; do
        read -r cmd port proto source_ip desc <<< "$rule"
        if [ -n "$port" ] && [ -n "$proto" ] && [ -n "$source_ip" ]; then
            $IPT -A INPUT -p "$proto" --dport "$port" -s "$source_ip" -m state --state NEW -j ACCEPT
            log "已开放端口: $port/$proto from $source_ip ${desc:+($desc)}"
        fi
    done
    
    # 应用端口转发规则
    log "应用端口转发规则..."
    for rule in "${FORWARD_PORTS[@]}"; do
        read -r cmd ext_port int_ip int_port proto desc <<< "$rule"
        if [ -n "$ext_port" ] && [ -n "$int_ip" ] && [ -n "$int_port" ] && [ -n "$proto" ]; then
            $IPT -t nat -A PREROUTING -p "$proto" --dport "$ext_port" -j DNAT --to-destination "$int_ip:$int_port"
            $IPT -A FORWARD -p "$proto" -d "$int_ip" --dport "$int_port" -j ACCEPT
            log "已添加转发: $ext_port -> $int_ip:$int_port/$proto ${desc:+($desc)}"
        fi
    done
    
    # ICMP 支持
    if [ "$ENABLE_ICMP" = "true" ]; then
        $IPT -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        $IPT -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
        log "ICMP 支持已启用"
    fi
    
    # 添加日志记录链 (如果启用)
    if [ "$ENABLE_DETAILED_LOGGING" = "true" ]; then
        $IPT -A INPUT -j LOGGING
    fi
    
    log "防火墙启动完成"
    log "当前规则统计: INPUT=$(iptables -L INPUT 2>/dev/null | grep -c '^ACCEPT\|^DROP\|^REJECT' || echo 0), FORWARD=$(iptables -L FORWARD 2>/dev/null | grep -c '^ACCEPT\|^DROP\|^REJECT' || echo 0)"
}

# 停止防火墙
stop_firewall() {
    log "停止 iptables-docker 防火墙..."
    
    # 创建备份
    create_backup
    
    # 保存 Docker 规则
    preserve_docker_rules
    
    # 设置默认策略为 ACCEPT
    $IPT -P INPUT ACCEPT
    $IPT -P FORWARD ACCEPT
    $IPT -P OUTPUT ACCEPT
    
    # 清空所有规则
    $IPT -F
    $IPT -X 2>/dev/null || true
    $IPT -t nat -F
    $IPT -t nat -X 2>/dev/null || true
    $IPT -t mangle -F
    $IPT -t mangle -X 2>/dev/null || true
    
    # 恢复 Docker 规则
    restore_docker_rules
    
    log "防火墙已停止 (Docker 规则已保留)"
}

# 重启防火墙
restart_firewall() {
    log "重启防火墙..."
    stop_firewall
    sleep 2
    start_firewall
}

# 显示当前规则
show_rules() {
    echo "========================================="
    echo "当前 INPUT 链规则:"
    echo "========================================="
    $IPT -L INPUT -n -v --line-numbers 2>/dev/null || echo "无法获取INPUT规则"
    echo ""
    echo "========================================="
    echo "当前 FORWARD 链规则:"
    echo "========================================="
    $IPT -L FORWARD -n -v --line-numbers 2>/dev/null || echo "无法获取FORWARD规则"
    echo ""
    echo "========================================="
    echo "当前 NAT 表规则:"
    echo "========================================="
    $IPT -t nat -L -n -v --line-numbers 2>/dev/null || echo "无法获取NAT规则"
    
    # 显示安全功能状态
    echo ""
    echo "========================================="
    echo "安全功能状态:"
    echo "========================================="
    load_security_config
    echo "反扫描保护: $ENABLE_ANTI_SCAN"
    echo "反IP欺骗保护: $ENABLE_ANTI_SPOOF"
    echo "SYN cookies: $ENABLE_SYN_COOKIES"
    echo "数据包过滤: $ENABLE_PACKET_FILTER"
    echo "详细日志: $ENABLE_DETAILED_LOGGING"
    echo "ICMP支持: $ENABLE_ICMP"
}

# 显示状态
show_status() {
    echo "========================================="
    echo "iptables-docker 防火墙状态"
    echo "========================================="
    echo "配置文件: $RULES_CONFIG"
    echo "安全配置: $SECURITY_CONFIG"
    echo "Docker规则: $DOCKER_RULES"
    echo "备份目录: $BACKUP_DIR"
    echo "日志文件: $LOG_FILE"
    echo ""
    
    # 检查规则数量
    local input_rules forward_rules nat_rules
    input_rules=$($IPT -L INPUT 2>/dev/null | grep -c '^ACCEPT\|^DROP\|^REJECT' || echo 0)
    forward_rules=$($IPT -L FORWARD 2>/dev/null | grep -c '^ACCEPT\|^DROP\|^REJECT' || echo 0)
    nat_rules=$($IPT -t nat -L 2>/dev/null | grep -c '^ACCEPT\|^DROP\|^REJECT\|^DNAT' || echo 0)
    
    echo "当前规则统计:"
    echo "  INPUT 链: $input_rules 条规则"
    echo "  FORWARD 链: $forward_rules 条规则"  
    echo "  NAT 表: $nat_rules 条规则"
    echo ""
    
    # 显示最近备份
    echo "最近的备份文件:"
    ls -lt "$BACKUP_DIR"/rules_* 2>/dev/null | head -5 | awk '{print "  " $9 " (" $6 " " $7 " " $8 ")"}' || echo "  无备份文件"
}

# 编辑配置文件
edit_config() {
    local config_type="${1:-rules}"
    local editor="${EDITOR:-vi}"
    local config_file
    
    case "$config_type" in
        rules|firewall)
            config_file="$RULES_CONFIG"
            ;;
        security|sec)
            config_file="$SECURITY_CONFIG"
            ;;
        *)
            echo "用法: $0 edit {rules|security}"
            echo "  rules    - 编辑防火墙规则配置"
            echo "  security - 编辑安全功能配置"
            return 1
            ;;
    esac
    
    if [ -f "$config_file" ]; then
        "$editor" "$config_file"
        echo "配置文件已修改,是否重新加载防火墙规则? (y/n)"
        read -r answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            restart_firewall
        fi
    else
        echo "错误: 配置文件不存在: $config_file"
        return 1
    fi
}

# 主程序
case "${1:-}" in
    start)
        start_firewall
        ;;
    stop)
        stop_firewall
        ;;
    restart)
        restart_firewall
        ;;
    status)
        show_status
        ;;
    show|rules)
        show_rules
        ;;
    edit)
        edit_config "${2:-rules}"
        ;;
    *)
        echo "增强版 iptables-docker 防火墙脚本"
        echo ""
        echo "用法: $0 {start|stop|restart|status|show|edit}"
        echo ""
        echo "命令说明:"
        echo "  start    - 启动防火墙"
        echo "  stop     - 停止防火墙 (保留 Docker 规则)"
        echo "  restart  - 重启防火墙"
        echo "  status   - 显示防火墙状态信息"
        echo "  show     - 显示当前详细规则"
        echo "  edit     - 编辑配置文件"
        echo "    edit rules    - 编辑防火墙规则配置"
        echo "    edit security - 编辑安全功能配置"
        echo ""
        echo "配置文件:"
        echo "  防火墙规则: $RULES_CONFIG"
        echo "  安全配置:   $SECURITY_CONFIG"
        echo "  日志文件:   $LOG_FILE"
        exit 1
        ;;
esac

exit 0