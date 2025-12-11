# 安装指南

## 系统要求

### 支持的操作系统

- Ubuntu 18.04 / 20.04 / 22.04 / 24.04
- Debian 10 / 11 / 12
- CentOS 7 / 8
- Rocky Linux 8 / 9
- AlmaLinux 8 / 9
- Fedora 35+

### 必需的软件包

- `iptables` (iptables-legacy)
- `systemctl` (systemd)
- `bash` (4.0+)
- `awk`
- Docker (如果需要 Docker 支持)

### 硬件要求

- 最小: 512MB RAM, 1 CPU 核心
- 推荐: 1GB+ RAM, 2+ CPU 核心
- 磁盘空间: 至少 100MB 可用空间

------

## 快速安装

### 方法 1: 自动安装 (推荐)

```bash
# 1. 下载项目
git clone https://github.com/YOUR_USERNAME/iptables-docker-enhanced.git
cd iptables-docker-enhanced

# 2. 运行安装脚本
sudo bash scripts/install.sh

# 3. 完成！
```

### 方法 2: 手动安装

```bash
# 1. 复制主脚本
sudo cp src/iptables-docker.sh /usr/local/sbin/iptables-docker.sh
sudo chmod +x /usr/local/sbin/iptables-docker.sh

# 2. 创建配置目录
sudo mkdir -p /etc/iptables-docker
sudo mkdir -p /var/lib/iptables-docker

# 3. 复制配置文件
sudo cp config/firewall-rules.conf.minimal /etc/iptables-docker/firewall-rules.conf

# 4. 创建 systemd 服务
sudo cp scripts/systemd/iptables-docker.service /etc/systemd/system/
sudo systemctl daemon-reload

# 5. 禁用冲突的防火墙
sudo systemctl stop ufw firewalld 2>/dev/null || true
sudo systemctl disable ufw firewalld 2>/dev/null || true

# 6. 配置 iptables-legacy
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy 2>/dev/null || true

# 7. 启动服务
sudo systemctl enable iptables-docker
sudo systemctl start iptables-docker
```

------

## 详细安装步骤

### 步骤 1: 准备系统

#### 1.1 更新系统

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt upgrade -y
```

**CentOS/Rocky/Alma:**

```bash
sudo yum update -y
# 或
sudo dnf update -y
```

#### 1.2 安装必需软件包

**Ubuntu/Debian:**

```bash
sudo apt install -y iptables git
```

**CentOS/Rocky/Alma:**

```bash
sudo yum install -y iptables git
# 或
sudo dnf install -y iptables git
```

#### 1.3 检查 Docker 安装 (如果使用 Docker)

```bash
# 检查 Docker 是否安装
docker --version

# 如果未安装，安装 Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker
```

### 步骤 2: 下载项目

```bash
# 使用 Git
git clone https://github.com/YOUR_USERNAME/iptables-docker-enhanced.git
cd iptables-docker-enhanced

# 或直接下载
wget https://github.com/YOUR_USERNAME/iptables-docker-enhanced/archive/refs/heads/main.zip
unzip main.zip
cd iptables-docker-enhanced-main
```

### 步骤 3: 配置 iptables

某些系统默认使用 nftables，需要切换到 iptables-legacy:

```bash
# 检查当前 iptables 版本
iptables --version

# 切换到 iptables-legacy
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# 验证切换
iptables --version  # 应该显示 legacy
```

### 步骤 4: 运行安装脚本

```bash
sudo bash scripts/install.sh
```

安装脚本会执行以下操作:

1. ✅ 检查系统依赖
2. ✅ 配置 iptables-legacy
3. ✅ 禁用 ufw 和 firewalld
4. ✅ 安装主脚本到 `/usr/local/sbin/`
5. ✅ 创建配置目录 `/etc/iptables-docker/`
6. ✅ 生成默认配置文件
7. ✅ 创建 systemd 服务
8. ✅ 启动防火墙服务

### 步骤 5: 验证安装

```bash
# 检查服务状态
sudo systemctl status iptables-docker

# 应该显示 "active (exited)" 和绿色的 "active"

# 查看防火墙规则
sudo iptables-docker.sh status

# 检查日志
sudo tail -f /var/log/iptables-docker.log
```

------

## 配置防火墙规则

### 编辑配置文件

```bash
# 方法 1: 使用内置编辑器
sudo iptables-docker.sh edit

# 方法 2: 直接编辑
sudo vi /etc/iptables-docker/firewall-rules.conf
```

### 基本配置示例

```bash
# SSH 访问
ALLOW_PORT 22 tcp 0.0.0.0/0 SSH

# Web 服务
ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP
ALLOW_PORT 443 tcp 0.0.0.0/0 HTTPS
```

### 应用配置

```bash
# 重启服务使配置生效
sudo systemctl restart iptables-docker

# 或使用脚本
sudo iptables-docker.sh restart
```

------

## 从其他防火墙迁移

### 从 ufw 迁移

```bash
# 1. 导出 ufw 规则 (参考)
sudo ufw status numbered > ufw-rules-backup.txt

# 2. 停用 ufw
sudo ufw disable
sudo systemctl disable ufw

# 3. 安装 iptables-docker-enhanced
sudo bash scripts/install.sh

# 4. 根据 ufw-rules-backup.txt 配置新规则
sudo iptables-docker.sh edit
```

### 从 firewalld 迁移

```bash
# 1. 导出 firewalld 规则 (参考)
sudo firewall-cmd --list-all > firewalld-rules-backup.txt

# 2. 停用 firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 3. 安装 iptables-docker-enhanced
sudo bash scripts/install.sh

# 4. 根据 firewalld-rules-backup.txt 配置新规则
sudo iptables-docker.sh edit
```

------

## 卸载

### 完全卸载

```bash
# 运行卸载脚本
sudo bash scripts/uninstall.sh

# 选择 'y' 删除所有配置文件
# 选择 'n' 保留配置文件以便将来使用
```

### 手动卸载

```bash
# 1. 停止并禁用服务
sudo systemctl stop iptables-docker
sudo systemctl disable iptables-docker

# 2. 删除服务文件
sudo rm -f /etc/systemd/system/iptables-docker.service
sudo systemctl daemon-reload

# 3. 删除脚本
sudo rm -f /usr/local/sbin/iptables-docker.sh

# 4. 删除配置 (可选)
sudo rm -rf /etc/iptables-docker
sudo rm -rf /var/lib/iptables-docker
sudo rm -f /var/log/iptables-docker.log
```

------

## 常见安装问题

### 问题 1: "iptables: command not found"

**解决方案:**

```bash
# Ubuntu/Debian
sudo apt install -y iptables

# CentOS/Rocky/Alma
sudo yum install -y iptables
```

### 问题 2: systemctl 命令不可用

**原因:** 系统未使用 systemd

**解决方案:** 手动运行脚本

```bash
# 启动
sudo /usr/local/sbin/iptables-docker.sh start

# 停止
sudo /usr/local/sbin/iptables-docker.sh stop
```

### 问题 3: 安装后 SSH 断开

**原因:** 防火墙配置错误，SSH 端口未开放

**预防措施:**

- 安装前确保配置文件包含 SSH 规则
- 使用控制台访问而非 SSH 进行首次配置
- 测试前备份现有防火墙规则

**恢复方法:**

```bash
# 通过控制台访问服务器
sudo iptables-docker.sh stop  # 临时停止防火墙
sudo iptables-docker.sh edit  # 添加 SSH 规则
sudo iptables-docker.sh start # 重启防火墙
```

### 问题 4: Docker 容器无法访问外网

**原因:** Docker 规则未正确保留

**解决方案:**

```bash
# 重启 Docker 和防火墙服务
sudo systemctl restart docker
sudo systemctl restart iptables-docker

# 验证 Docker 网络
docker run --rm alpine ping -c 3 google.com
```

------

## 升级

### 从旧版本升级

```bash
# 1. 备份现有配置
sudo cp /etc/iptables-docker/firewall-rules.conf \
       /etc/iptables-docker/firewall-rules.conf.backup

# 2. 下载新版本
cd /tmp
git clone https://github.com/YOUR_USERNAME/iptables-docker-enhanced.git
cd iptables-docker-enhanced

# 3. 运行安装脚本 (会保留配置)
sudo bash scripts/install.sh

# 4. 重启服务
sudo systemctl restart iptables-docker

# 5. 验证升级
sudo iptables-docker.sh status
```

------

## 下一步

安装完成后，建议:

1. 📖 阅读 [使用指南](https://claude.ai/chat/USAGE.md)
2. 🔧 配置适合你的防火墙规则
3. 📊 查看 [配置示例](https://claude.ai/examples/)
4. ❓ 如有问题，查看 [故障排查](https://claude.ai/chat/TROUBLESHOOTING.md)

------

## 获取帮助

- 📚 查看文档: [docs/](https://claude.ai/docs/)
- 💬 提交问题: [GitHub Issues](https://github.com/YOUR_USERNAME/iptables-docker-enhanced/issues)
- 📧 联系支持: your-email@example.com