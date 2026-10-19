# Day 3 学习指南：面试准备 + 项目收尾

## 今日目标
1. 完善项目文档和 README
2. 掌握运维面试常见问题及回答技巧
3. 准备项目介绍话术
4. 模拟面试练习

---

## 第一部分：项目介绍话术（面试必用）

### 1. 项目概述（30秒版本）
> "我最近完成了一个 LNMP 自动化部署与运维监控项目。这个项目使用 Docker Compose 一键部署 Nginx、MySQL、PHP 环境，并配套编写了5个运维脚本，包括自动化部署、健康检查、数据库备份、日志分析和系统监控。通过这个项目，我掌握了 Linux 常用命令、Shell 脚本编程、Docker 容器化部署和 MySQL 运维等核心技能。"

### 2. 技术亮点（面试官追问时）
- **容器化部署**：使用 Docker Compose 实现一键部署，支持环境变量配置，便于不同环境迁移
- **自动化运维**：5个脚本覆盖部署、监控、备份、日志分析全流程，减少人工操作
- **安全加固**：数据库密码通过环境变量管理，权限最小化原则，防火墙配置
- **监控告警**：实时监控 CPU、内存、磁盘使用情况，设置告警阈值
- **日志分析**：自动分析 Nginx 访问日志，统计 PV/UV、状态码、热门 URL，发现异常请求

### 3. 项目难点及解决方案
**难点1：Docker 容器间通信**
- 问题：Nginx 容器如何访问 PHP 和 MySQL 容器？
- 解决：使用 Docker Compose 的 networks 功能，创建自定义网络，容器间通过服务名通信

**难点2：数据库备份的完整性**
- 问题：如何保证备份过程中数据的一致性？
- 解决：使用 mysqldump 的 --single-transaction 参数，保证 InnoDB 表的一致性备份

**难点3：日志分析的准确性**
- 问题：如何从大量日志中快速定位问题？
- 解决：使用 awk、sort、uniq 命令组合，按维度统计，设置异常阈值告警

---

## 第二部分：运维面试常见问题

### 一、Linux 基础（必考）

**Q1: 如何查看一个文件的大小？**
```bash
ls -lh filename
du -h filename
stat filename
```

**Q2: 如何查看一个进程占用的端口？**
```bash
netstat -tlnp | grep PID
ss -tlnp | grep PID
lsof -i :端口号
```

**Q3: 如何实时查看日志文件？**
```bash
tail -f /var/log/nginx/access.log
```

**Q4: 如何查找大于100M的文件？**
```bash
find / -size +100M -type f
```

**Q5: 如何修改文件权限为 755？**
```bash
chmod 755 filename
# 755 = rwxr-xr-x
# 所有者：读写执行
# 组和其他人：读和执行
```

**Q6: 如何查看系统负载？**
```bash
uptime
# 输出：load average: 0.5, 0.3, 0.2
# 分别表示1分钟、5分钟、15分钟的平均负载
# 如果负载超过CPU核心数，说明系统过载
```

**Q7: 如何杀死一个进程？**
```bash
kill PID          # 发送SIGTERM信号，优雅退出
kill -9 PID       # 发送SIGKILL信号，强制杀死
kill -15 PID      # 同kill，发送SIGTERM
pkill -f "进程名"  # 按名称杀死进程
```

### 二、MySQL 相关（必考）

**Q1: 如何备份和恢复 MySQL 数据库？**
```bash
# 备份
mysqldump -u root -p database_name > backup.sql

# 恢复
mysql -u root -p database_name < backup.sql

# 压缩备份
mysqldump -u root -p database_name | gzip > backup.sql.gz
```

**Q2: 如何查看 MySQL 的慢查询？**
```sql
-- 开启慢查询日志
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;

-- 查看慢查询配置
SHOW VARIABLES LIKE 'slow_query%';
```

**Q3: 如何优化 MySQL 查询？**
- 使用 EXPLAIN 分析查询执行计划
- 为常用查询字段添加索引
- 避免 SELECT *，只查询需要的字段
- 使用 LIMIT 限制返回行数
- 避免在 WHERE 子句中使用函数

**Q4: MySQL 的索引类型有哪些？**
- 主键索引（PRIMARY KEY）
- 唯一索引（UNIQUE）
- 普通索引（INDEX）
- 组合索引（多列索引）
- 全文索引（FULLTEXT）

**Q5: 如何查看 MySQL 当前的连接数？**
```sql
SHOW STATUS LIKE 'Threads%';
SHOW PROCESSLIST;
```

### 三、Docker 相关（高频）

**Q1: Docker 和虚拟机的区别？**
- Docker 是容器化技术，共享宿主机内核，启动快（秒级），资源占用少
- 虚拟机有完整的操作系统，启动慢（分钟级），资源占用多
- Docker 适合微服务部署，虚拟机适合需要完整OS隔离的场景

**Q2: Docker 常用命令有哪些？**
```bash
docker ps                    # 查看运行中的容器
docker images                # 查看本地镜像
docker pull image            # 拉取镜像
docker run -d -p 80:80 nginx # 运行容器
docker logs container        # 查看日志
docker exec -it container bash  # 进入容器
docker-compose up -d         # 启动所有服务
docker-compose down          # 停止所有服务
```

**Q3: Dockerfile 和 docker-compose.yml 的区别？**
- Dockerfile：定义单个镜像的构建过程
- docker-compose.yml：定义多个容器的编排和依赖关系

**Q4: 如何进入一个运行中的 Docker 容器？**
```bash
docker exec -it container_name bash
# 或
docker exec -it container_name sh
```

**Q5: Docker 容器之间如何通信？**
- 使用 Docker Compose 的 networks 功能
- 容器间通过服务名（容器名）通信
- 例如：Nginx 容器通过 "php:9000" 访问 PHP 容器

### 四、网络相关（高频）

**Q1: TCP 三次握手的过程？**
```
1. 客户端发送 SYN 包到服务器
2. 服务器收到 SYN，发送 SYN+ACK 包
3. 客户端收到 SYN+ACK，发送 ACK 包
连接建立完成
```

**Q2: TCP 和 UDP 的区别？**
- TCP：面向连接、可靠传输、有序、有流量控制、速度较慢
- UDP：无连接、不可靠、无序、无流量控制、速度快
- TCP 用于 HTTP、FTP、SMTP 等需要可靠传输的场景
- UDP 用于视频流、DNS 查询等对速度要求高的场景

**Q3: HTTP 状态码有哪些？**
- 200：成功
- 301：永久重定向
- 302：临时重定向
- 400：请求错误
- 401：未授权
- 403：禁止访问
- 404：未找到
- 500：服务器内部错误
- 502：网关错误
- 503：服务不可用

**Q4: 如何排查网络问题？**
```bash
# 1. 检查网络连通性
ping 目标IP

# 2. 检查端口是否开放
telnet 目标IP 端口
nc -zv 目标IP 端口

# 3. 查看路由
traceroute 目标IP

# 4. 抓包分析
tcpdump -i eth0 port 80

# 5. 查看本地端口监听
netstat -tlnp
```

**Q5: DNS 解析的过程？**
```
1. 浏览器检查本地缓存
2. 检查操作系统缓存
3. 查询本地DNS服务器
4. 本地DNS服务器查询根DNS
5. 根DNS返回顶级域DNS
6. 顶级域DNS返回权威DNS
7. 权威DNS返回IP地址
```

### 五、Shell 脚本相关（高频）

**Q1: Shell 脚本中 `$?` 是什么意思？**
答：`$?` 表示上一个命令的退出状态码。0表示成功，非0表示失败。

**Q2: 如何调试 Shell 脚本？**
```bash
bash -x script.sh  # 显示每条命令的执行过程
bash -n script.sh  # 检查语法错误
```

**Q3: Shell 脚本中单引号和双引号的区别？**
- 单引号：原样输出，不解析变量
- 双引号：会解析变量

```bash
NAME="张三"
echo '$NAME'    # 输出：$NAME
echo "$NAME"    # 输出：张三
```

**Q4: 如何设置定时任务？**
```bash
crontab -e  # 编辑定时任务

# 格式：分 时 日 月 周 命令
# 示例：每天凌晨2点执行备份
0 2 * * * /path/to/backup.sh
```

### 六、场景题（综合）

**Q1: 网站访问很慢，如何排查？**
```
1. 检查服务器资源（CPU、内存、磁盘）
   top, free -h, df -h

2. 检查网络连接
   ping, traceroute

3. 检查服务状态
   systemctl status nginx
   docker-compose ps

4. 查看日志
   tail -f /var/log/nginx/error.log
   docker logs container_name

5. 检查数据库
   SHOW PROCESSLIST;
   查看慢查询日志

6. 检查网络带宽
   iftop, nload
```

**Q2: MySQL 数据库突然无法连接，如何排查？**
```
1. 检查 MySQL 服务是否运行
   systemctl status mysql
   docker ps | grep mysql

2. 检查端口是否监听
   netstat -tlnp | grep 3306

3. 检查防火墙
   firewall-cmd --list-ports
   iptables -L

4. 查看错误日志
   tail -f /var/log/mysql/error.log
   docker logs lnmp-mysql

5. 检查磁盘空间
   df -h

6. 检查连接数是否满了
   SHOW STATUS LIKE 'Threads%';
```

**Q3: 磁盘空间满了，如何清理？**
```bash
# 1. 查看磁盘使用情况
df -h

# 2. 查找大文件
find / -size +100M -type f

# 3. 查看目录大小
du -sh /var/*

# 4. 清理日志
> /var/log/nginx/access.log
truncate -s 0 /var/log/mysql/error.log

# 5. 清理Docker
docker system prune -a

# 6. 清理临时文件
rm -rf /tmp/*
```

---

## 第三部分：面试技巧

### 1. 自我介绍模板
> "面试官您好，我是XX大学软件工程专业的应届毕业生。我对运维工程师岗位非常感兴趣。
> 
> 在技术方面，我掌握了 Linux 常用命令，能够进行日常的系统管理和故障排查；熟悉 MySQL 数据库的增删改查和备份恢复操作；了解 Docker 容器化技术，能够使用 Docker Compose 部署和管理多容器应用；具备 Shell 脚本编程能力，能够编写自动化运维脚本。
> 
> 最近我完成了一个 LNMP 自动化部署与运维监控项目，通过这个项目我深入理解了运维工作的全流程，包括环境部署、服务监控、日志分析、数据库备份等。
> 
> 我有很强的学习能力和问题解决能力，遇到问题会主动查阅文档和日志，善于使用 AI 工具辅助定位问题。希望能有机会加入贵公司，在导师的指导下快速成长。"

### 2. 回答问题的 STAR 法则
- **S**ituation（情境）：描述背景
- **T**ask（任务）：说明你的任务
- **A**ction（行动）：你采取了什么行动
- **R**esult（结果）：取得了什么结果

**示例：**
> "在我的 LNMP 项目中（情境），我需要实现数据库的自动备份（任务）。我编写了一个 Shell 脚本，使用 mysqldump 进行全量备份，并设置了 crontab 定时任务每天凌晨2点自动执行（行动）。最终实现了数据库的自动化备份，并且脚本会自动清理30天前的旧备份，节省磁盘空间（结果）。"

### 3. 面试注意事项
- 遇到不会的问题，诚实说"这个我不太了解，但我会去学习"
- 回答问题时，先说结论，再展开说明
- 结合项目经验回答问题，更有说服力
- 展示你的学习能力和主动性
- 准备1-2个问题问面试官（体现你的兴趣）

---

## 第四部分：简历项目描述

### 项目名称：LNMP 自动化部署与运维监控平台

### 项目描述：
基于 Docker Compose 的 LNMP（Linux + Nginx + MySQL + PHP）环境自动化部署与运维监控系统，实现了一键部署、健康检查、数据库备份、日志分析和系统监控等功能。

### 技术栈：
Linux、Docker、Docker Compose、Nginx、MySQL、PHP、Shell

### 主要工作：
1. 使用 Docker Compose 编排 Nginx、MySQL、PHP 三个容器，实现一键部署
2. 编写 Shell 脚本实现自动化部署、健康检查、数据库备份、日志分析和系统监控
3. 配置 Nginx 反向代理和静态资源缓存，优化访问性能
4. 实现 MySQL 定时备份策略，支持全量备份和增量备份
5. 开发日志分析工具，统计 PV/UV、状态码分布、热门 URL 等指标
6. 编写系统监控脚本，实时监控 CPU、内存、磁盘使用情况

### 项目成果：
- 部署时间从手动30分钟缩短到自动5分钟
- 实现7×24小时自动化监控，及时发现服务异常
- 数据库备份自动化，数据安全性提升

---

## 今日作业
1. 熟读并背诵项目介绍话术
2. 练习所有面试常见问题
3. 完善简历中的项目描述
4. 模拟面试：找同学或对着镜子练习
5. 复习 Day 1 和 Day 2 的内容
6. 确保项目能在虚拟机中正常运行

---

## 面试前检查清单
- [ ] 项目能在虚拟机中正常运行
- [ ] 能独立部署 LNMP 环境
- [ ] 能解释每个脚本的功能和实现原理
- [ ] 熟悉 Linux 常用命令
- [ ] 熟悉 MySQL 常用操作
- [ ] 熟悉 Docker 常用命令
- [ ] 了解网络基础知识
- [ ] 准备好自我介绍
- [ ] 准备好项目介绍
- [ ] 准备好1-2个问题问面试官
