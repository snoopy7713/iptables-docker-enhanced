# 增强版 iptables-docker 安装和使用指南

## 功能特性

### 🔥 融合两版本优势

- ✅ **配置文件驱动管理** - 通过配置文件灵活管理防火墙规则
- ✅ **完整安全防护** - 包含反扫描、反欺骗、反SYN flood等安全功能
- ✅ **Docker兼容性** - 完美保持Docker网络功能
- ✅ **自动备份** - 每次操作都会自动备份当前规则
- ✅ **详细日志** - 完整的操作日志和安全事件记录

### 🛡️ 安全防护功能

- **反扫描保护** - 检测和阻止端口扫描攻击
- **反IP欺骗保护** - 启用反向路径过滤
- **反SYN Flood保护** - 启用SYN cookies防DDoS
- **恶意数据包过滤** - 过滤分片包、广播包等恶意流量
- **详细日志记录** - 记录被阻止的攻击尝试

### 📋 规则管理功能

- **端口开放规则** - `ALLOW_PORT 端口 协议 源IP 描述`
- **源IP白名单** - `ALLOW_SOURCE IP/CIDR 描述`
- **端口转发规则** - `FORWARD_PORT 外部端口 内部IP 内部端口 协议 描述`

## 快速安装

### 1. 下载和安装脚本

```bash
# 下载脚本文件
sudo mkdir -p /usr/local/sbin
sudo wget -O /usr/local/sbin/iptables-docker.sh [脚本URL]
sudo chmod +x /usr/local/sbin/iptables-docker.sh

# 安装systemd服务文件
sudo wget -O /etc/systemd/system/iptables-docker.service [服务文件URL]
sudo systemctl daemon-reload
```

### 2. 初始配置

```bash
# 初次运行会自动创建配置文件
sudo /usr/local/sbin/iptables-docker.sh start

# 或者先编辑配置再启动
sudo /usr/local/sbin/iptables-docker.sh edit rules
```

## 配置文件说明

### 防火墙规则配置文件

位置：`/etc/iptables-docker/firewall-rules.conf`

```bash
# 开放SSH访问
ALLOW_PORT 22 tcp 0.0.0.0/0 SSH远程访问

# 开放Web服务（仅限特定网段）
ALLOW_PORT 80 tcp 192.168.1.0/24 HTTP服务
ALLOW_PORT 443 tcp 192.168.1.0/24 HTTPS服务

# 允许特定IP访问所有服务
ALLOW_SOURCE 192.168.1.100 管理员机器

# 端口转发到容器
FORWARD_PORT 8080 172.17.0.2 80 tcp Web容器转发

# Docker Swarm端口（如需要）
ALLOW_PORT 2377 tcp 192.168.1.0/24 Swarm管理端口
ALLOW_PORT 7946 tcp 192.168.1.0/24 Swarm节点通信
ALLOW_PORT 7946 udp 192.168.1.0/24 Swarm节点通信
ALLOW_PORT 4789 udp 192.168.1.0/24 Swarm overlay网络
```

### 安全配置文件

位置：`/etc/iptables-docker/security.conf`

```bash
# 安全功能开关（true=启用，false=禁用）
ENABLE_ANTI_SCAN=true          # 反扫描保护
ENABLE_ANTI_SPOOF=true         # 反IP欺骗保护
ENABLE_SYN_COOKIES=true        # 反SYN Flood保护
ENABLE_PACKET_FILTER=true      # 恶意数据包过滤
ENABLE_DETAILED_LOGGING=true   # 详细日志记录
LOG_LIMIT_RATE=2               # 日志记录频率限制
ENABLE_ICMP=true               # 允许ICMP（ping）
```

## 使用方法

### 基本命令

```bash
# 启动防火墙
sudo systemctl start iptables-docker
# 或
sudo /usr/local/sbin/iptables-docker.sh start

# 停止防火墙（保留Docker规则）
sudo systemctl stop iptables-docker
# 或
sudo /usr/local/sbin/iptables-docker.sh stop

# 重启防火墙
sudo systemctl restart iptables-docker
# 或
sudo /usr/local/sbin/iptables-docker.sh restart

# 设置开机自启动
sudo systemctl enable iptables-docker
```

### 状态查看

```bash
# 查看防火墙状态
sudo /usr/local/sbin/iptables-docker.sh status

# 查看详细规则
sudo /usr/local/sbin/iptables-docker.sh show

# 查看服务状态
sudo systemctl status iptables-docker
```

### 配置管理

```bash
# 编辑防火墙规则
sudo /usr/local/sbin/iptables-docker.sh edit rules

# 编辑安全配置
sudo /usr/local/sbin/iptables-docker.sh edit security

# 修改后重新加载
sudo /usr/local/sbin/iptables-docker.sh restart
```

## 日志和备份

### 日志文件

- **主日志**：`/var/log/iptables-docker.log` - 操作日志
- **系统日志**：`/var/log/messages` 或 `journalctl -u iptables-docker` - 被阻止的攻击日志

### 规则备份

- **备份目录**：`/var/lib/iptables-docker/backup/`
- **自动备份**：每次启动/停止时自动备份
- **保留策略**：自动保留最近10个备份文件

```bash
# 查看备份文件
ls -la /var/lib/iptables-docker/backup/

# 手动恢复备份（谨慎操作）
sudo iptables-restore < /var/lib/iptables-docker/backup/rules_20231211120000
```

## 常见使用场景

### 1. Web服务器配置

```bash
# 开放Web端口给所有人
ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP服务
ALLOW_PORT 443 tcp 0.0.0.0/0 HTTPS服务

# SSH仅允许特定网段
ALLOW_PORT 22 tcp 192.168.1.0/24 SSH管理
```

### 2. 数据库服务器配置

```bash
# 数据库仅允许内网访问
ALLOW_PORT 3306 tcp 192.168.1.0/24 MySQL数据库
ALLOW_PORT 5432 tcp 192.168.1.0/24 PostgreSQL数据库

# 允许应用服务器IP
ALLOW_SOURCE 192.168.1.50 应用服务器
ALLOW_SOURCE 192.168.1.51 应用服务器
```

### 3. Docker Swarm集群配置

```bash
# Swarm管理端口
ALLOW_PORT 2377 tcp 10.0.0.0/8 Swarm管理端口

# 节点间通信端口  
ALLOW_PORT 7946 tcp 10.0.0.0/8 Swarm节点通信
ALLOW_PORT 7946 udp 10.0.0.0/8 Swarm节点通信

# Overlay网络端口
ALLOW_PORT 4789 udp 10.0.0.0/8 Swarm overlay网络
```

### 4. 容器端口映射

```bash
# 转发外部8080到容器80端口
FORWARD_PORT 8080 172.17.0.2 80 tcp Web应用容器

# 转发外部3306到容器内部数据库
FORWARD_PORT 3306 172.17.0.3 3306 tcp MySQL容器
```

## 安全建议

### 1. 最小权限原则

- 只开放必要的端口
- 限制源IP范围，避免使用 `0.0.0.0/0`
- 定期审查规则配置

### 2. 监控和维护

```bash
# 定期查看日志
sudo tail -f /var/log/iptables-docker.log

# 监控被阻止的攻击
sudo journalctl -f | grep "IPTables-Dropped"

# 定期检查规则状态
sudo /usr/local/sbin/iptables-docker.sh status
```

### 3. 备份和恢复

- 配置文件加入版本控制
- 定期备份配置目录
- 测试环境先验证规则

## 故障排除

### 常见问题

**1. Docker容器网络不通**

```bash
# 检查Docker相关规则是否正确加载
sudo iptables -L FORWARD -v -n | grep docker

# 重启防火墙服务
sudo systemctl restart iptables-docker
```

**2. SSH连接被断开**

```bash
# 确保SSH规则正确配置
grep "ALLOW_PORT.*22" /etc/iptables-docker/firewall-rules.conf

# 紧急恢复（直接停止防火墙）
sudo systemctl stop iptables-docker
```

**3. 配置文件语法错误**

```bash
# 检查配置文件语法
sudo /usr/local/sbin/iptables-docker.sh start

# 查看详细错误信息
sudo journalctl -u iptables-docker -n 50
```

### 调试模式

```bash
# 启用调试输出
sudo TRACE=1 /usr/local/sbin/iptables-docker.sh start

# 查看详细日志
sudo tail -f /var/log/iptables-docker.log
```

## 版本升级

当有新版本发布时：

```bash
# 备份当前配置
sudo cp -r /etc/iptables-docker /etc/iptables-docker.backup

# 更新脚本文件
sudo wget -O /usr/local/sbin/iptables-docker.sh [新版本URL]
sudo chmod +x /usr/local/sbin/iptables-docker.sh

# 重启服务
sudo systemctl restart iptables-docker
```

## 技术支持

如遇到问题，请提供以下信息：

- 操作系统版本
- Docker版本
- 配置文件内容
- 错误日志信息
- 当前iptables规则输出
