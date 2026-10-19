# Day 2 学习指南：Shell 脚本编程 + 网络基础

## 今日目标
1. 掌握 Shell 脚本编程基础（变量、循环、条件判断、函数）
2. 理解项目中的5个运维脚本
3. 掌握计算机网络基础（TCP/IP、DNS、HTTP）
4. 学会使用抓包和网络排查工具

---

## 第一部分：Shell 脚本编程基础

### 1. 变量
```bash
# 定义变量（等号两边不能有空格！）
NAME="张三"
AGE=25
PORT=8080

# 使用变量
echo "姓名: $NAME"
echo "年龄: ${AGE}"

# 特殊变量
echo "脚本名: $0"
echo "第一个参数: $1"
echo "参数个数: $#"
echo "所有参数: $@"
echo "上一个命令的返回值: $?"  # 0表示成功，非0表示失败
echo "当前进程PID: $$"

# 只读变量
readonly PI=3.14

# 删除变量
unset NAME
```

### 2. 条件判断
```bash
# 文件判断
if [ -f "/etc/passwd" ]; then
    echo "文件存在"
fi

if [ -d "/home/user" ]; then
    echo "目录存在"
fi

if [ -r "/etc/passwd" ]; then
    echo "文件可读"
fi

# 字符串判断
if [ "$STR1" = "$STR2" ]; then
    echo "字符串相等"
fi

if [ -z "$STR" ]; then
    echo "字符串为空"
fi

# 数值比较
if [ $AGE -gt 18 ]; then
    echo "已成年"
fi

# 常用比较运算符
# -eq 等于, -ne 不等于, -gt 大于, -lt 小于, -ge 大于等于, -le 小于等于

# 逻辑运算
if [ $AGE -gt 18 ] && [ $AGE -lt 60 ]; then
    echo "劳动年龄"
fi

if [ $SCORE -lt 60 ] || [ $SCORE -gt 100 ]; then
    echo "成绩异常"
fi
```

### 3. 循环
```bash
# for 循环
for i in 1 2 3 4 5; do
    echo "数字: $i"
done

# 遍历文件
for file in *.log; do
    echo "处理文件: $file"
done

# C风格 for 循环
for ((i=0; i<10; i++)); do
    echo "计数: $i"
done

# while 循环
COUNT=0
while [ $COUNT -lt 5 ]; do
    echo "计数: $COUNT"
    COUNT=$((COUNT + 1))
done

# 读取文件
while read line; do
    echo "行内容: $line"
done < file.txt
```

### 4. 函数
```bash
# 定义函数
function greet() {
    local name=$1  # local 声明局部变量
    echo "你好, $name!"
}

# 调用函数
greet "张三"

# 带返回值的函数
function check_service() {
    local service=$1
    if systemctl is-active --quiet $service; then
        return 0  # 成功
    else
        return 1  # 失败
    fi
}

# 使用返回值
if check_service nginx; then
    echo "Nginx 运行正常"
else
    echo "Nginx 未运行"
fi
```

### 5. 实战：编写一个简单的服务监控脚本
```bash
#!/bin/bash
# 监控脚本示例

SERVICES=("nginx" "mysql" "redis")
LOG_FILE="/var/log/service_monitor.log"

check_service() {
    local service=$1
    
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [OK] $service 运行正常" | tee -a "$LOG_FILE"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [FAIL] $service 未运行，尝试重启..." | tee -a "$LOG_FILE"
        systemctl restart $service
        return 1
    fi
}

# 主循环
for service in "${SERVICES[@]}"; do
    check_service $service
done
```

---

## 第二部分：项目脚本详解

### 1. deploy.sh - 一键部署脚本
**核心逻辑：**
1. 检查系统环境（操作系统、root权限）
2. 安装 Docker（如果未安装）
3. 安装 Docker Compose（如果未安装）
4. 创建必要目录
5. 配置环境变量（.env文件）
6. 启动 Docker Compose 服务
7. 验证部署结果

**面试要点：**
- `set -e`：遇到错误立即退出，防止错误累积
- 颜色输出：提高脚本可读性
- 函数化设计：每个功能一个函数，便于维护

### 2. health_check.sh - 健康检查脚本
**检查项目：**
- Docker 守护进程状态
- 容器运行状态
- Nginx HTTP响应
- MySQL 连接状态
- 系统资源（CPU、内存、磁盘）

**面试要点：**
- 如何判断服务是否健康？（HTTP状态码、端口监听、进程存在）
- 如何生成检查报告？

### 3. mysql_backup.sh - 数据库备份脚本
**备份策略：**
- 全量备份：mysqldump 导出整个数据库
- 增量备份：基于 binlog 的增量备份
- 自动清理：删除30天前的旧备份
- 备份验证：gzip -t 验证备份文件完整性

**面试要点：**
- 备份和恢复的命令
- 如何保证备份的完整性？
- 如何设置定时任务？

### 4. log_analyzer.sh - 日志分析脚本
**分析维度：**
- PV/UV 统计
- HTTP 状态码分布
- 热门 URL
- 热门 IP
- 异常请求（4xx、5xx错误）
- 访问时间分布

**面试要点：**
- awk、sort、uniq 命令的组合使用
- 如何从日志中发现异常？

### 5. monitor.sh - 系统监控脚本
**监控指标：**
- CPU 使用率
- 内存使用率
- 磁盘使用率
- Docker 容器状态
- 网络连接状态
- Top 进程

**面试要点：**
- 如何获取系统资源使用情况？
- 如何设置告警阈值？

---

## 第三部分：计算机网络基础

### 1. TCP/IP 模型（面试必考）
```
应用层    HTTP, FTP, SMTP, DNS
传输层    TCP, UDP
网络层    IP, ICMP
网络接口层  Ethernet, WiFi
```

### 2. TCP 三次握手（面试高频）
```
客户端 -> SYN -> 服务器
客户端 <- SYN+ACK <- 服务器
客户端 -> ACK -> 服务器
```
**为什么需要三次握手？**
- 防止已失效的连接请求报文段突然又传送到了服务端
- 双方确认对方的发送和接收能力

### 3. TCP 四次挥手
```
客户端 -> FIN -> 服务器
客户端 <- ACK <- 服务器
客户端 <- FIN <- 服务器
客户端 -> ACK -> 服务器
```
**为什么需要四次挥手？**
- TCP是全双工的，每个方向必须单独关闭

### 4. DNS 解析过程
```
1. 浏览器检查本地缓存
2. 检查操作系统缓存
3. 查询本地DNS服务器
4. 本地DNS服务器查询根DNS
5. 根DNS返回顶级域DNS
6. 顶级域DNS返回权威DNS
7. 权威DNS返回IP地址
```

### 5. HTTP 状态码（面试必考）
```
2xx 成功
  200 OK - 请求成功
  201 Created - 资源创建成功

3xx 重定向
  301 Moved Permanently - 永久重定向
  302 Found - 临时重定向
  304 Not Modified - 缓存未修改

4xx 客户端错误
  400 Bad Request - 请求语法错误
  401 Unauthorized - 未授权
  403 Forbidden - 禁止访问
  404 Not Found - 资源不存在

5xx 服务器错误
  500 Internal Server Error - 服务器内部错误
  502 Bad Gateway - 网关错误
  503 Service Unavailable - 服务不可用
  504 Gateway Timeout - 网关超时
```

### 6. 常用网络排查命令
```bash
# 测试连通性
ping baidu.com

# 查看路由
traceroute baidu.com

# 查看端口监听
netstat -tlnp
ss -tlnp

# 抓包分析
tcpdump -i eth0 port 80
tcpdump -i eth0 host 192.168.1.100

# 测试端口
telnet localhost 3306
nc -zv localhost 3306

# 查看网络连接
netstat -an | grep ESTABLISHED
ss -s  # 连接统计
```

---

## 第四部分：定时任务（Crontab）

### 1. Crontab 基本用法
```bash
# 编辑定时任务
crontab -e

# 查看定时任务
crontab -l

# 删除所有定时任务
crontab -r
```

### 2. Crontab 格式
```
* * * * * command
分 时 日 月 周 命令

# 示例
0 2 * * * /path/to/mysql_backup.sh full        # 每天凌晨2点备份
*/5 * * * * /path/to/health_check.sh           # 每5分钟检查一次
0 */1 * * * /path/to/log_analyzer.sh           # 每小时分析日志
```

### 3. 为项目设置定时任务
```bash
# 编辑 crontab
crontab -e

# 添加以下内容
# MySQL 每天凌晨2点全量备份
0 2 * * * /home/user/lnmp-ops-project/scripts/mysql_backup.sh full >> /home/user/lnmp-ops-project/logs/cron.log 2>&1

# 每5分钟健康检查
*/5 * * * * /home/user/lnmp-ops-project/scripts/health_check.sh >> /home/user/lnmp-ops-project/logs/cron.log 2>&1

# 每小时日志分析
0 * * * * /home/user/lnmp-ops-project/scripts/log_analyzer.sh >> /home/user/lnmp-ops-project/logs/cron.log 2>&1
```

---

## 面试常见问题（Day 2 相关）

### Q1: Shell 脚本中 `$?` 是什么意思？
答：`$?` 表示上一个命令的退出状态码。0表示成功，非0表示失败。

### Q2: 如何调试 Shell 脚本？
```bash
bash -x script.sh  # 显示每条命令的执行过程
bash -n script.sh  # 检查语法错误
```

### Q3: TCP 和 UDP 的区别？
- TCP：面向连接、可靠传输、有序、有流量控制、速度较慢
- UDP：无连接、不可靠、无序、无流量控制、速度快

### Q4: 如何查看一个端口被哪个进程占用？
```bash
netstat -tlnp | grep 8080
lsof -i :8080
ss -tlnp | grep 8080
```

### Q5: HTTP 和 HTTPS 的区别？
- HTTP 是明文传输，HTTPS 是加密传输（SSL/TLS）
- HTTP 默认端口 80，HTTPS 默认端口 443
- HTTPS 需要 SSL 证书

### Q6: 什么是负载均衡？
答：将用户请求分发到多个服务器上，提高系统的可用性和性能。常见算法：轮询、加权轮询、最少连接、IP哈希。

---

## 今日作业
1. 阅读并理解项目中的5个 Shell 脚本
2. 手动运行每个脚本，观察输出结果
3. 修改脚本中的某些参数，观察变化
4. 练习上面列出的所有网络命令
5. 设置 crontab 定时任务
6. 尝试自己写一个简单的监控脚本
