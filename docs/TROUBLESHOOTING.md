# 故障排查指南

遇到问题？这里有详细的排查步骤和解决方案。

------

## 快速诊断

### 运行诊断命令

```bash
# 检查服务状态
sudo systemctl status iptables-docker

# 查看最近的日志
sudo journalctl -u iptables-docker.service -n 50

# 查看防火墙规则
sudo iptables-docker.sh status

# 查看脚本日志
sudo tail -n 100 /var/log/iptables-docker.log
```

------

## 常见问题

### 1. 服务无法启动

**症状:**

```bash
sudo systemctl start iptables-docker
# 失败或无响应
```

**排查步骤:**

```bash
# 1. 查看详细错误信息
sudo systemctl status iptables-docker -l
sudo journalctl -u iptables-docker.service -n 50

# 2. 检查脚本是否存在
ls -la /usr/local/sbin/iptables-docker.sh

# 3. 检查脚本权限
sudo chmod +x /usr/local/sbin/iptables-docker.sh

# 4. 手动运行脚本测试
sudo /usr/local/sbin/iptables-docker.sh start

# 5. 检查配置文件
cat /etc/iptables-docker/firewall-rules.conf
```

**常见原因:**

- 脚本文件缺失或权限不正确
- 配置文件语法错误
- iptables 命令不可用

**解决方案:**

```bash
# 重新安装
cd /path/to/iptables-docker-enhanced
sudo bash scripts/install.sh
```

------

### 2. 端口无法访问

**症状:**

- 无法通过特定端口访问服务
- 连接超时或被拒绝

**排查步骤:**

```bash
# 步骤 1: 检查服务是否在监听
sudo netstat -tuln | grep :<端口号>
# 或
sudo ss -tuln | grep :<端口号>

# 步骤 2: 检查防火墙规则
sudo iptables -L INPUT -n -v | grep <端口号>

# 步骤 3: 检查配置文件
grep "ALLOW_PORT <端口号>" /etc/iptables-docker/firewall-rules.conf

# 步骤 4: 测试本地连接
curl localhost:<端口号>
telnet localhost <端口号>

# 步骤 5: 从外部测试
# 在另一台机器上运行
telnet <服务器IP> <端口号>
nc -zv <服务器IP> <端口号>
```

**解决方案:**

```bash
# 如果服务未监听
sudo systemctl restart <服务名>

# 如果规则缺失
sudo vi /etc/iptables-docker/firewall-rules.conf
# 添加规则: ALLOW_PORT <端口> tcp 0.0.0.0/0 描述
sudo systemctl restart iptables-docker

# 如果规则存在但不生效
sudo systemctl restart iptables-docker
sudo iptables -L INPUT -n -v
```

------

### 3. Docker 容器网络异常

**症状:**

- 容器无法访问外网
- 容器端口映射不工作
- 容器间无法通信

**排查步骤:**

```bash
# 步骤 1: 测试容器网络
docker run --rm alpine ping -c 3 google.com

# 步骤 2: 检查 Docker 规则
sudo iptables -t nat -L DOCKER -n -v
sudo iptables -L DOCKER -n -v
sudo iptables -L FORWARD -n -v

# 步骤 3: 查看 Docker 网络
docker network ls
docker network inspect bridge

# 步骤 4: 检查 Docker 服务
sudo systemctl status docker
```

**解决方案:**

```bash
# 方案 1: 重启服务
sudo systemctl restart docker
sudo systemctl restart iptables-docker

# 方案 2: 手动恢复 Docker 规则
sudo /usr/local/sbin/iptables-docker.sh restart

# 方案 3: 重建 Docker 网络
docker network prune -f
sudo systemctl restart docker

# 方案 4: 检查 Docker daemon 配置
sudo vi /etc/docker/daemon.json
# 确保没有禁用 iptables
# "iptables": true
sudo systemctl restart docker
```

------

### 4. SSH 连接被拒绝

**症状:**

- 无法通过 SSH 连接服务器
- 连接超时

**紧急恢复:**

⚠️ **警告:** 如果你被锁在外面，需要通过控制台访问！

```bash
# 通过控制台登录后执行:

# 临时关闭防火墙
sudo /usr/local/sbin/iptables-docker.sh stop

# 或直接清空 INPUT 规则
sudo iptables -P INPUT ACCEPT
sudo iptables -F INPUT

# 测试 SSH 连接
# 从外部: ssh user@server-ip

# 修复配置
sudo vi /etc/iptables-docker/firewall-rules.conf
# 确保有 SSH 规则:
# ALLOW_PORT 22 tcp 0.0.0.0/0 SSH

# 重启防火墙
sudo /usr/local/sbin/iptables-docker.sh start
```

**预防措施:**

```bash
# 1. 始终保留 SSH 规则
ALLOW_PORT 22 tcp 0.0.0.0/0 SSH

# 2. 使用多个备用访问方式
ALLOW_PORT 22 tcp 0.0.0.0/0 SSH标准端口
ALLOW_PORT 2222 tcp 0.0.0.0/0 SSH备用端口

# 3. 测试前保持一个 SSH 会话
# 在另一个终端保持连接，测试新配置
# 如果失败，可以在旧会话中恢复

# 4. 使用定时任务自动恢复
# 设置 5 分钟后恢复旧规则（测试用）
(sleep 300 && sudo cp firewall-rules.conf.backup /etc/iptables-docker/firewall-rules.conf && sudo systemctl restart iptables-docker) &
```

------

### 5. 配置修改不生效

**症状:**

- 修改了配置文件但规则未更新
- 重启服务后仍使用旧规则

**排查步骤:**

```bash
# 1. 检查配置文件内容
cat /etc/iptables-docker/firewall-rules.conf

# 2. 检查配置文件语法
# 查找常见错误:
# - 缺少空格
# - 协议写错 (必须是 tcp 或 udp)
# - IP 格式错误

# 3. 手动重载
sudo systemctl restart iptables-docker

# 4. 查看加载日志
sudo tail -f /var/log/iptables-docker.log

# 5. 验证规则
sudo iptables -L INPUT -n -v
```

**常见语法错误:**

```bash
# ❌ 错误: 缺少空格
ALLOW_PORT 80tcp 0.0.0.0/0 HTTP

# ✅ 正确
ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP

# ❌ 错误: 协议名称错误
ALLOW_PORT 80 TCP 0.0.0.0/0 HTTP

# ✅ 正确
ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP

# ❌ 错误: IP 格式错误
ALLOW_PORT 80 tcp 192.168.1 HTTP

# ✅ 正确
ALLOW_PORT 80 tcp 192.168.1.0/24 HTTP
```

------

### 6. 日志文件过大

**症状:**

- /var/log/iptables-docker.log 占用大量空间

**解决方案:**

```bash
# 查看日志文件大小
ls -lh /var/log/iptables-docker.log

# 清空日志
sudo truncate -s 0 /var/log/iptables-docker.log

# 或删除后重新创建
sudo rm /var/log/iptables-docker.log
sudo systemctl restart iptables-docker

# 设置日志轮转
sudo vi /etc/logrotate.d/iptables-docker
```

内容:

```
/var/log/iptables-docker.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
```

------

### 7. 规则加载缓慢

**症状:**

- 防火墙启动时间过长
- 系统重启后需要等待很久

**原因:**

- 规则数量过多
- Docker 容器数量较多

**优化建议:**

```bash
# 1. 合并 IP 规则
# 不推荐:
ALLOW_PORT 22 tcp 192.168.1.1 用户1
ALLOW_PORT 22 tcp 192.168.1.2 用户2
# ...100 行

# 推荐:
ALLOW_PORT 22 tcp 192.168.1.0/24 内网用户

# 2. 使用源IP白名单
# 如果某个IP需要访问多个端口:
ALLOW_SOURCE 192.168.1.100 管理员
# 而不是每个端口单独写规则

# 3. 删除无用规则
sudo vi /etc/iptables-docker/firewall-rules.conf
# 删除注释掉的或不再使用的规则
```

------

### 8. 与其他防火墙冲突

**症状:**

- 同时运行了 ufw 或 firewalld
- 规则相互覆盖

**检查:**

```bash
# 检查 ufw
sudo systemctl status ufw
sudo ufw status

# 检查 firewalld
sudo systemctl status firewalld
sudo firewall-cmd --state
```

**解决方案:**

```bash
# 禁用 ufw
sudo systemctl stop ufw
sudo systemctl disable ufw

# 禁用 firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 重启 iptables-docker
sudo systemctl restart iptables-docker
```

------

## 高级调试

### 启用详细日志

编辑脚本临时启用调试模式:

```bash
sudo vi /usr/local/sbin/iptables-docker.sh

# 在脚本开头添加
set -x  # 启用调试输出

# 运行测试
sudo /usr/local/sbin/iptables-docker.sh start

# 查看详细输出
sudo journalctl -u iptables-docker.service -n 200
```

### 跟踪数据包

使用 iptables 的日志功能:

```bash
# 临时添加日志规则
sudo iptables -I INPUT -p tcp --dport 80 -j LOG --log-prefix "HTTP: "

# 查看内核日志
sudo dmesg | tail -f
# 或
sudo tail -f /var/log/kern.log

# 测试后删除日志规则
sudo iptables -D INPUT -p tcp --dport 80 -j LOG --log-prefix "HTTP: "
```

### 逐条测试规则

```bash
# 1. 停止防火墙
sudo systemctl stop iptables-docker

# 2. 清空所有规则
sudo iptables -F
sudo iptables -P INPUT ACCEPT

# 3. 手动添加规则测试
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# 4. 测试连接
curl localhost:80

# 5. 确认规则有效后，更新配置文件
```

------

## 错误代码参考

### 常见错误消息

#### "iptables: command not found"

**原因:** iptables 未安装

**解决:**

```bash
# Ubuntu/Debian
sudo apt install iptables

# CentOS/Rocky
sudo yum install iptables
```

#### "Permission denied"

**原因:** 权限不足

**解决:**

```bash
# 使用 sudo 运行
sudo iptables-docker.sh start
```

#### "Bad argument"

**原因:** iptables 命令参数错误

**解决:**

```bash
# 检查配置文件语法
sudo vi /etc/iptables-docker/firewall-rules.conf

# 查看详细错误
sudo journalctl -u iptables-docker.service -n 50
```

------

## 获取帮助

### 收集诊断信息

在提交问题前，请收集以下信息:

```bash
#!/bin/bash
# 诊断信息收集脚本

echo "=== 系统信息 ===" > debug-info.txt
uname -a >> debug-info.txt
cat /etc/os-release >> debug-info.txt

echo -e "\n=== 服务状态 ===" >> debug-info.txt
systemctl status iptables-docker >> debug-info.txt 2>&1

echo -e "\n=== 配置文件 ===" >> debug-info.txt
cat /etc/iptables-docker/firewall-rules.conf >> debug-info.txt

echo -e "\n=== 当前规则 ===" >> debug-info.txt
iptables -L -n -v >> debug-info.txt
iptables -t nat -L -n -v >> debug-info.txt

echo -e "\n=== 最近日志 ===" >> debug-info.txt
tail -n 100 /var/log/iptables-docker.log >> debug-info.txt
journalctl -u iptables-docker.service -n 100 >> debug-info.txt 2>&1

echo -e "\n=== Docker 信息 ===" >> debug-info.txt
docker --version >> debug-info.txt 2>&1
docker ps >> debug-info.txt 2>&1

echo "诊断信息已保存到 debug-info.txt"
```

### 联系支持

- 📧 Email: support@example.com
- 🐛 GitHub Issues: https://github.com/YOUR_USERNAME/iptables-docker-enhanced/issues
- 💬 讨论区: https://github.com/YOUR_USERNAME/iptables-docker-enhanced/discussions

提交问题时请附上 `debug-info.txt` 文件。

------

## 相关文档

- 📖 [安装指南](https://claude.ai/chat/INSTALL.md)
- 📝 [使用指南](https://claude.ai/chat/USAGE.md)
- ❓ [常见问题](https://claude.ai/chat/FAQ.md)