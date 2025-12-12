# iptables-docker-enhanced 防火墙管理 - 安装和使用指南

基于 iptables-docker 的增强版本，支持通过配置文件简单管理防火墙规则。



## 目录结构

```
/opt/iptables-docker/scripts/
├── iptables-docker.sh    # 主脚本
├── parse_yaml.py         # YAML解析器
└── awk.firewall          # Docker规则提取器（可选）

/etc/iptables-docker/
├── firewall.yaml         # 防火墙规则配置（YAML格式）
└── security.conf         # 安全功能配置

/var/lib/iptables-docker/
├── docker.rules          # 保存的Docker规则
└── backup/               # 规则备份目录
    ├── rules_20241212120000
    └── ...

/var/log/
└── iptables-docker.log   # 日志文件
```

## 安装步骤

### 1. 下载脚本文件

```bash
# 创建脚本目录
mkdir -p /opt/iptables-docker
cd /opt/iptables-docker

# 下载主脚本和解析器
# (假设你已经有这些文件)
chmod +x iptables-docker.sh
chmod +x parse_yaml.py
```

### 2. 安装 Python 依赖

```bash
# 检查 Python3
python3 --version

# 安装 PyYAML
pip3 install pyyaml

# 或者使用系统包管理器
# Ubuntu/Debian
sudo apt install python3-yaml

# CentOS/RHEL
sudo yum install python3-pyyaml

# Fedora
sudo dnf install python3-pyyaml
```

### 3. 首次运行初始化

```bash
# 初始化配置（会自动创建配置目录和默认配置文件）
sudo ./iptables-docker.sh start
```

### 4. 设置开机自启（可选）

#### 方式一：使用 systemd

创建服务文件 `/etc/systemd/system/iptables-docker.service`：

```ini
[Unit]
Description=iptables-docker Firewall
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/iptables-docker/iptables-docker.sh start
ExecStop=/opt/iptables-docker/iptables-docker.sh stop
ExecReload=/opt/iptables-docker/iptables-docker.sh restart

[Install]
WantedBy=multi-user.target
```

启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable iptables-docker
sudo systemctl start iptables-docker
```

#### 方式二：使用 rc.local（传统方式）

```bash
# 添加到 /etc/rc.local
echo "/opt/iptables-docker/iptables-docker.sh start" >> /etc/rc.local
chmod +x /etc/rc.local
```

## 配置文件说明

### firewall.yaml - 防火墙规则配置

```yaml
# 开放端口规则
allow-ports:
  - port: 22           # 端口号
    proto: tcp         # 协议 (tcp/udp)
    sources:           # 允许的源IP列表
      - 192.168.1.0/24 # 可以带注释
      - 10.0.0.1       # 单个IP
    description: "SSH访问"  # 规则描述

# 允许源IP规则（所有端口）
allow-sources:
  - ip: 192.168.1.100
    description: "管理员机器"

# Docker容器端口白名单
docker-ports:
  - port: 8080
    proto: tcp
    sources:
      - 192.168.1.0/24
    description: "Web容器"

# 端口转发规则
forward-ports:
  - external: 8080
    internal-ip: 172.17.0.2
    internal-port: 80
    proto: tcp
    description: "转发到容器"
```

### security.conf - 安全功能配置

```bash
# 启用/禁用安全功能 (true/false)
ENABLE_ANTI_SCAN=true          # 反扫描保护
ENABLE_ANTI_SPOOF=true         # 反IP欺骗保护
ENABLE_SYN_COOKIES=true        # 反SYN Flood保护
ENABLE_PACKET_FILTER=true      # 恶意数据包过滤
ENABLE_DETAILED_LOGGING=true   # 详细日志记录
LOG_LIMIT_RATE=2               # 日志频率限制(条/分钟)
ENABLE_ICMP=true               # ICMP支持(允许ping)
```

## 常用命令

### 基本操作

```bash
# 启动防火墙
sudo ./iptables-docker.sh start

# 停止防火墙（保留Docker规则）
sudo ./iptables-docker.sh stop

# 重启防火墙（修改配置后需要重启）
sudo ./iptables-docker.sh restart

# 查看状态信息
sudo ./iptables-docker.sh status

# 显示当前详细规则
sudo ./iptables-docker.sh show
```

### 配置编辑

```bash
# 编辑防火墙规则（会提示是否重启）
sudo ./iptables-docker.sh edit rules

# 编辑安全配置
sudo ./iptables-docker.sh edit security

# 或者直接编辑配置文件
sudo vim /etc/iptables-docker/firewall.yaml
sudo ./iptables-docker.sh restart
```

### 格式转换

```bash
# 将旧的 .conf 格式转换为 .yaml 格式
sudo ./iptables-docker.sh convert
```

## 使用场景示例

### 场景 1：开放 Web 服务给所有人

```yaml
allow-ports:
  - port: 80
    proto: tcp
    sources:
      - 0.0.0.0/0
    description: "HTTP服务"
  
  - port: 443
    proto: tcp
    sources:
      - 0.0.0.0/0
    description: "HTTPS服务"
```

### 场景 2：SSH 只允许特定IP访问

```yaml
allow-ports:
  - port: 22
    proto: tcp
    sources:
      - 192.168.1.100    # 办公室IP
      - 203.0.113.50     # 家里IP
      - 10.0.0.0/8       # VPN网段
    description: "SSH远程访问"
```

### 场景 3：Docker 容器数据库只允许内网访问

```yaml
docker-ports:
  - port: 3306
    proto: tcp
    sources:
      - 192.168.1.0/24   # 内网
      - 10.0.0.0/8       # VPN
    description: "MySQL容器"
```

### 场景 4：信任的管理员机器完全访问

```yaml
allow-sources:
  - ip: 192.168.1.100
    description: "管理员工作站 - 完全访问"
```

### 场景 5：端口转发到内部容器

```yaml
forward-ports:
  - external: 8080
    internal-ip: 172.17.0.2
    internal-port: 80
    proto: tcp
    description: "转发到nginx容器"
```

## 检查和调试

### 查看日志

```bash
# 查看实时日志
sudo tail -f /var/log/iptables-docker.log

# 查看系统日志中被拦截的包
sudo tail -f /var/log/syslog | grep "IPTables-Dropped"
# 或者
sudo journalctl -f | grep "IPTables-Dropped"
```

### 查看当前规则

```bash
# 查看 INPUT 链
sudo iptables -L INPUT -n -v --line-numbers

# 查看 FORWARD 链
sudo iptables -L FORWARD -n -v --line-numbers

# 查看 NAT 表
sudo iptables -t nat -L -n -v --line-numbers

# 查看 Docker 相关链
sudo iptables -L DOCKER -n -v
sudo iptables -L DOCKER-USER -n -v
```

### 测试防火墙规则

```bash
# 从另一台机器测试端口
telnet <服务器IP> 22
nc -zv <服务器IP> 80

# 测试 ping
ping <服务器IP>

# 查看连接状态
sudo ss -tlnp  # TCP监听端口
sudo ss -ulnp  # UDP监听端口
```

## 故障排除

### 问题 1：防火墙启动后无法访问服务

**原因：** 可能没有添加相应的规则

**解决：**

```bash
# 1. 检查配置文件
sudo cat /etc/iptables-docker/firewall.yaml

# 2. 临时停止防火墙测试
sudo ./iptables-docker.sh stop

# 3. 如果停止后可以访问，说明是规则问题，添加正确的规则后重启
```

### 问题 2：Docker 容器无法访问外网

**原因：** Docker 规则未正确恢复

**解决：**

```bash
# 1. 检查 Docker 规则文件
sudo cat /var/lib/iptables-docker/docker.rules

# 2. 查看 FORWARD 链
sudo iptables -L FORWARD -n -v

# 3. 重启 Docker 服务
sudo systemctl restart docker

# 4. 重启防火墙
sudo ./iptables-docker.sh restart
```

### 问题 3：PyYAML 安装失败

**原因：** 网络问题或权限问题

**解决：**

```bash
# 使用系统包管理器安装
sudo apt install python3-yaml  # Ubuntu/Debian
sudo yum install python3-pyyaml  # CentOS/RHEL

# 或使用国内镜像
pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple pyyaml

# 如果还是不行，可以使用 .conf 格式
sudo mv /etc/iptables-docker/firewall.yaml /etc/iptables-docker/firewall.conf
# 然后使用传统格式编辑配置
```

### 问题 4：规则加载后立即失效

**原因：** 可能是 Docker 重启清空了规则

**解决：**

```bash
# 添加 Docker 事件监听（自动恢复规则）
# 创建 /etc/docker/daemon.json
{
  "iptables": true
}

# 重启 Docker
sudo systemctl restart docker
sudo ./iptables-docker.sh restart
```

## 备份和恢复

### 手动备份

```bash
# 备份配置文件
sudo cp /etc/iptables-docker/firewall.yaml /backup/firewall.yaml.$(date +%Y%m%d)

# 备份当前规则
sudo iptables-save > /backup/iptables.rules.$(date +%Y%m%d)
```

### 从备份恢复

```bash
# 恢复配置文件
sudo cp /backup/firewall.yaml.20241212 /etc/iptables-docker/firewall.yaml
sudo ./iptables-docker.sh restart

# 恢复规则
sudo iptables-restore < /backup/iptables.rules.20241212
```

### 自动备份

脚本在每次启动和停止时会自动备份到：

```
/var/lib/iptables-docker/backup/rules_YYYYMMDDHHMMSS
```

保留最近 10 个备份文件。

## 安全最佳实践

1. **最小权限原则**

   - 只开放必要的端口
   - 使用 CIDR 限制源IP范围

2. **SSH 安全**

   - 限制 SSH 访问的源IP
   - 考虑使用非标准端口
   - 启用密钥认证

3. **定期审查**

   ```bash
   # 每月检查一次规则
   sudo ./iptables-docker.sh show
   ```

4. **监控日志**

   ```bash
   # 设置日志监控告警
   sudo tail -f /var/log/syslog | grep "IPTables-Dropped"
   ```

5. **测试环境先试**

   - 在生产环境应用前，先在测试环境验证规则

## 性能优化

1. **减少日志记录**

   ```bash
   # 在 security.conf 中调整
   ENABLE_DETAILED_LOGGING=false
   ```

2. **优化规则顺序**

   - 将最常用的规则放在前面
   - 使用 `allow-sources` 对信任IP完全放行

3. **监控资源使用**

   ```bash
   # 查看 iptables 性能
   sudo iptables -L -n -v --line-numbers
   ```

## 更新和维护

### 更新脚本

```bash
# 备份当前版本
sudo cp /opt/iptables-docker/iptables-docker.sh /opt/iptables-docker/iptables-docker.sh.bak

# 下载新版本
cd /opt/iptables-docker
# ... 更新文件

# 测试新版本
sudo ./iptables-docker.sh status
```

### 定期维护

```bash
# 每月任务
# 1. 清理旧日志
sudo truncate -s 0 /var/log/iptables-docker.log

# 2. 检查规则有效性
sudo ./iptables-docker.sh show

# 3. 更新配置
sudo ./iptables-docker.sh edit rules
```

## 联系和支持

如有问题，请检查：

1. 日志文件：`/var/log/iptables-docker.log`
2. 系统日志：`/var/log/syslog` 或 `journalctl -xe`
3. 配置文件语法：使用 YAML 在线验证器检查格式
