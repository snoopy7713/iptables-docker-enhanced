# 常见问题解答 (FAQ)

------

## 一般问题

### Q1: 这个项目和原始的 iptables-docker 有什么区别？

**A:** 主要区别在于配置方式:

| 特性     | 原版                 | Enhanced版         |
| -------- | -------------------- | ------------------ |
| 配置方式 | 修改脚本代码         | 编辑配置文件       |
| 规则管理 | 手动编写iptables命令 | 简单的配置语法     |
| 易用性   | 需要了解iptables     | 不需要iptables知识 |
| 维护性   | 升级需要合并代码     | 配置文件独立       |

### Q2: 是否支持 IPv6？

**A:** 当前版本主要支持 IPv4。IPv6 支持计划在未来版本中添加。

临时解决方案:

```bash
# 禁用 IPv6 (如果不需要)
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

### Q3: 可以在生产环境使用吗？

**A:** 可以，但建议:

1. 先在测试环境验证
2. 做好配置备份
3. 保持一个控制台会话以防被锁定
4. 逐步迁移，不要一次性修改所有规则

### Q4: 需要重启服务器吗？

**A:** 不需要。安装和配置变更都不需要重启服务器，只需要重启防火墙服务:

```bash
sudo systemctl restart iptables-docker
```

### Q5: 会影响现有的 Docker 容器吗？

**A:** 不会。脚本会保留所有 Docker 相关的 iptables 规则，容器网络不受影响。

------

## 安装相关

### Q6: 支持哪些 Linux 发行版？

**A:** 支持主流发行版:

- ✅ Ubuntu 18.04+
- ✅ Debian 10+
- ✅ CentOS 7+
- ✅ Rocky Linux 8+
- ✅ AlmaLinux 8+
- ✅ Fedora 35+

### Q7: 可以和 ufw 或 firewalld 一起使用吗？

**A:** 不建议。安装时会自动禁用 ufw 和 firewalld，因为多个防火墙工具会相互冲突。

如果需要使用其他防火墙工具，请卸载 iptables-docker-enhanced:

```bash
sudo bash scripts/uninstall.sh
```

### Q8: 安装失败怎么办？

**A:** 请检查:

1. 是否使用 root 或 sudo 权限
2. 系统是否支持 systemd
3. iptables 是否已安装

查看详细错误:

```bash
sudo bash scripts/install.sh 2>&1 | tee install.log
```

### Q9: 如何完全卸载？

**A:** 运行卸载脚本:

```bash
sudo bash scripts/uninstall.sh
# 选择 'y' 删除所有配置
```

------

## 配置相关

### Q10: 如何开放一个端口给所有人访问？

**A:**

```bash
ALLOW_PORT <端口> tcp 0.0.0.0/0 描述
```

示例:

```bash
ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP服务
ALLOW_PORT 443 tcp 0.0.0.0/0 HTTPS服务
```

### Q11: 如何只允许特定IP访问？

**A:**

```bash
ALLOW_PORT <端口> tcp <IP地址> 描述
```

示例:

```bash
# 单个IP
ALLOW_PORT 22 tcp 192.168.1.100 管理员

# IP段
ALLOW_PORT 3306 tcp 192.168.1.0/24 内网数据库访问
```

### Q12: 如何允许多个IP访问同一端口？

**A:** 三种方法:

```bash
# 方法1: 多行规则 (推荐)
ALLOW_PORT 22 tcp 192.168.1.100 管理员1
ALLOW_PORT 22 tcp 192.168.1.101 管理员2
ALLOW_PORT 22 tcp 192.168.1.102 管理员3

# 方法2: 使用CIDR (如果IP连续)
ALLOW_PORT 22 tcp 192.168.1.100/29 管理员组

# 方法3: 源IP白名单 (如果需要访问多个端口)
ALLOW_SOURCE 192.168.1.100 管理员1
ALLOW_SOURCE 192.168.1.101 管理员2
ALLOW_PORT 22 tcp 0.0.0.0/0 SSH
```

### Q13: 配置文件的注释怎么写？

**A:** 使用 `#` 号:

```bash
# 这是注释
ALLOW_PORT 80 tcp 0.0.0.0/0 HTTP  # 行尾注释也可以
```

### Q14: 如何禁用某条规则而不删除？

**A:** 在规则前加 `#`:

```bash
# ALLOW_PORT 8080 tcp 0.0.0.0/0 临时禁用的服务
```

### Q15: 配置文件有字数限制吗？

**A:** 没有。可以添加任意数量的规则，但建议:

- 使用 CIDR 合并连续IP
- 删除不用的规则
- 添加清晰的注释和分组

------

## Docker 相关

### Q16: Docker 容器无法访问外网怎么办？

**A:**

```bash
# 重启服务
sudo systemctl restart docker
sudo systemctl restart iptables-docker

# 测试
docker run --rm alpine ping -c 3 google.com
```

### Q17: 如何开放 Docker 容器端口？

**A:** Docker 会自动处理端口映射。只需正常运行容器:

```bash
docker run -d -p 8080:80 nginx
```

防火墙会自动允许这个端口。

### Q18: Docker Swarm 需要开放哪些端口？

**A:** 参考 `examples/docker-swarm.conf`:

```bash
ALLOW_PORT 2377 tcp 192.168.1.0/24 Swarm管理
ALLOW_PORT 7946 tcp 192.168.1.0/24 节点通信TCP
ALLOW_PORT 7946 udp 192.168.1.0/24 节点通信UDP
ALLOW_PORT 4789 udp 192.168.1.0/24 Overlay网络
```

### Q19: 如何使用端口转发？

**A:**

```bash
FORWARD_PORT <外部端口> <内部IP> <内部端口> <协议> 描述
```

示例:

```bash
# 转发到容器
FORWARD_PORT 8080 172.17.0.2 80 tcp Nginx容器

# 转发到内网服务器
FORWARD_PORT 9000 192.168.1.50 8080 tcp 应用服务器
```

------

## 安全相关

### Q20: 默认策略是什么？

**A:**

- INPUT: DROP (默认拒绝所有入站)
- FORWARD: DROP (默认拒绝所有转发)
- OUTPUT: ACCEPT (默认允许所有出站)

### Q21: 如何保护 SSH？

**A:** 几种方法:

```bash
# 方法1: 限制IP
ALLOW_PORT 22 tcp 192.168.1.0/24 内网SSH

# 方法2: 使用非标准端口
ALLOW_PORT 2222 tcp 0.0.0.0/0 SSH非标准端口
# (需要同时修改 /etc/ssh/sshd_config)

# 方法3: 多层防护
ALLOW_PORT 22 tcp 192.168.1.100 管理员
# + 使用密钥认证
# + 禁用密码登录
# + 安装 fail2ban
```

### Q22: 如何防止被自己锁定？

**A:** 安全措施:

1. **保持一个 SSH 会话**

   ```bash
   # 在测试新配置前，打开两个SSH会话
   # 一个用于测试，一个用于恢复
   ```

2. **设置自动恢复**

   ```bash
   # 创建备份
   sudo cp /etc/iptables-docker/firewall-rules.conf /etc/iptables-docker/firewall-rules.conf.backup
   
   # 设置5分钟后自动恢复
   (sleep 300 && sudo cp /etc/iptables-docker/firewall-rules.conf.backup /etc/iptables-docker/firewall-rules.conf && sudo systemctl restart iptables-docker) &
   
   # 如果5分钟内测试成功，杀死自动恢复进程
   ps aux | grep sleep
   kill <PID>
   ```

3. **使用控制台**

   - 云服务器通常提供 VNC 或串口控制台
   - 即使 SSH 被锁定也能访问

### Q23: 如何查看被拒绝的连接？

**A:** 启用日志:

```bash
# 临时添加日志规则
sudo iptables -I INPUT -j LOG --log-prefix "FIREWALL-DROP: " --log-level 4

# 查看日志
sudo tail -f /var/log/kern.log | grep FIREWALL-DROP

# 测试完成后删除
sudo iptables -D INPUT -j LOG --log-prefix "FIREWALL-DROP: " --log-level 4
```

------

## 性能相关

### Q24: 会影响网络性能吗？

**A:** 影响很小。iptables 是内核级防火墙，性能开销极低。

优化建议:

- 常用规则放在前面
- 使用 CIDR 合并IP段
- 避免过多的单独规则

### Q25: 可以处理多少规则？

**A:** 理论上无限制，但建议:

- 小型环境: < 50 条规则
- 中型环境: < 200 条规则
- 大型环境: < 500 条规则

超过 500 条考虑使用 ipset 或其他方案。

### Q26: 如何优化规则？

**A:**

```bash
# 不推荐: 100个单独IP
ALLOW_PORT 22 tcp 192.168.1.1 用户1
ALLOW_PORT 22 tcp 192.168.1.2 用户2
# ...

# 推荐: 使用CIDR
ALLOW_PORT 22 tcp 192.168.1.0/24 内网用户

# 或使用源IP白名单
ALLOW_SOURCE 192.168.1.0/24 内网用户
```

------

## 故障排查

### Q27: 修改配置后不生效怎么办？

**A:**

```bash
# 1. 检查语法
cat /etc/iptables-docker/firewall-rules.conf

# 2. 重启服务
sudo systemctl restart iptables-docker

# 3. 查看日志
sudo journalctl -u iptables-docker.service -n 50
sudo tail -f /var/log/iptables-docker.log

# 4. 验证规则
sudo iptables -L INPUT -n -v
```

### Q28: 如何测试端口是否开放？

**A:**

```bash
# 从本机测试
telnet localhost <端口>
nc -zv localhost <端口>

# 从外部测试
telnet <服务器IP> <端口>
nc -zv <服务器IP> <端口>

# 使用 nmap
nmap -p <端口> <服务器IP>
```

### Q29: 服务无法启动怎么办？

**A:** 查看 [故障排查指南](https://claude.ai/chat/TROUBLESHOOTING.md)

快速检查:

```bash
# 查看状态
sudo systemctl status iptables-docker -l

# 查看日志
sudo journalctl -u iptables-docker.service -n 100

# 手动运行
sudo /usr/local/sbin/iptables-docker.sh start
```

------

## 高级用法

### Q30: 可以设置速率限制吗？

**A:** 当前版本不直接支持，但可以手动添加:

```bash
# 编辑脚本添加速率限制规则
sudo vi /usr/local/sbin/iptables-docker.sh

# 在规则应用区域添加:
$IPT -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
```

### Q31: 支持地理位置封禁吗？

**A:** 不直接支持。建议使用专门的 GeoIP 工具:

- `xtables-addons` (GeoIP 模块)
- `ipset` + GeoIP 数据库

### Q32: 如何集成到 CI/CD？

**A:** 示例:

```yaml
# GitLab CI 示例
deploy:
  script:
    - scp firewall-rules.conf user@server:/etc/iptables-docker/
    - ssh user@server "sudo systemctl restart iptables-docker"
```

### Q33: 可以用配置管理工具部署吗？

**A:** 可以。示例:

**Ansible:**

```yaml
- name: Deploy firewall rules
  copy:
    src: firewall-rules.conf
    dest: /etc/iptables-docker/firewall-rules.conf
  notify: restart iptables-docker

- name: Restart firewall
  systemd:
    name: iptables-docker
    state: restarted
```

------

## 其他问题

### Q34: 如何贡献代码？

**A:**

1. Fork 项目
2. 创建功能分支
3. 提交 Pull Request

详见: [CONTRIBUTING.md](https://claude.ai/chat/CONTRIBUTING.md)

### Q35: 有商业支持吗？

**A:** 这是一个开源项目，暂无商业支持。如有需求请联系: your-email@example.com

### Q36: 未来会添加哪些功能？

**A:** 计划中的功能:

- [ ] IPv6 支持
- [ ] Web 管理界面
- [ ] 规则导入/导出
- [ ] 速率限制支持
- [ ] GeoIP 封禁
- [ ] 更多配置模板

### Q37: 如何报告 Bug？

**A:**

1. 访问 [GitHub Issues](https://github.com/YOUR_USERNAME/iptables-docker-enhanced/issues)
2. 搜索是否已有相同问题
3. 创建新 Issue 并附上:
   - 系统信息
   - 配置文件
   - 错误日志
   - 复现步骤

### Q38: 项目许可证是什么？

**A:** GPL-3.0 License

可以自由:

- ✅ 使用
- ✅ 修改
- ✅ 分发

但必须:

- ⚠️ 开源修改后的代码
- ⚠️ 保留原始许可证和版权声明

------

## 还有问题？

- 📖 查看 [完整文档](https://claude.ai/docs/)
- 💬 加入 [讨论区](https://github.com/YOUR_USERNAME/iptables-docker-enhanced/discussions)
- 📧 发送邮件: support@example.com
- 🐛 提交 Issue: https://github.com/YOUR_USERNAME/iptables-docker-enhanced/issues