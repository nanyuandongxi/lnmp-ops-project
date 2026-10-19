# Day 1 学习指南：Linux 命令强化 + MySQL 进阶 + Docker 环境搭建

## 今日目标
1. 掌握运维面试必考的 Linux 常用命令
2. 掌握 MySQL 进阶操作（权限、备份、慢查询）
3. 安装 Docker 和 Docker Compose
4. 理解并运行 LNMP 项目的 Docker Compose 配置

---

## 第一部分：Linux 常用命令（面试必考）

### 1. 文件与目录操作
```bash
# 查看文件内容
cat file.txt          # 显示整个文件
less file.txt         # 分页查看（空格翻页，q退出）
tail -f file.txt      # 实时查看文件末尾（看日志必备！）
tail -100 file.txt    # 查看最后100行
head -20 file.txt     # 查看前20行

# 文件搜索
find / -name "*.log"              # 按文件名搜索
find / -size +100M                # 查找大于100M的文件
grep -rn "error" /var/log/        # 在文件中搜索内容（-r递归，-n显示行号）
grep -i "error" file.txt          # 忽略大小写搜索

# 文件权限
chmod 755 script.sh    # 设置权限（rwxr-xr-x）
chown user:group file  # 修改所有者
# 权限数字：r=4, w=2, x=1
# 755 = rwxr-xr-x (所有者读写执行，其他人读执行)
# 644 = rw-r--r-- (所有者读写，其他人只读)
```

### 2. 进程管理
```bash
ps aux                    # 查看所有进程
ps aux | grep nginx       # 查找特定进程
top                       # 实时查看系统资源（q退出）
kill -9 PID               # 强制结束进程
kill -15 PID              # 优雅结束进程
```

### 3. 网络命令（面试高频）
```bash
ping baidu.com            # 测试网络连通性
curl http://localhost:8080  # 测试HTTP服务
netstat -tlnp             # 查看监听端口
ss -tlnp                  # netstat的替代品（更快）
ifconfig / ip addr        # 查看IP地址
telnet localhost 3306     # 测试端口是否开放
```

### 4. 系统信息
```bash
uname -a                  # 系统信息
df -h                     # 磁盘使用情况
free -h                   # 内存使用情况
uptime                    # 系统运行时间和负载
whoami                    # 当前用户
```

### 5. 日志分析（运维核心技能）
```bash
# 统计访问日志中的IP数量
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10

# 统计HTTP状态码
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# 查找特定时间段的日志
grep "16/Oct/2026" access.log

# 统计错误数量
grep -c "ERROR" error.log
```

---

## 第二部分：MySQL 进阶操作

### 1. 用户与权限管理
```sql
-- 创建用户
CREATE USER 'newuser'@'%' IDENTIFIED BY 'password123';

-- 授权
GRANT ALL PRIVILEGES ON database_name.* TO 'newuser'@'%';
GRANT SELECT, INSERT, UPDATE ON database_name.* TO 'readonly_user'@'%';

-- 刷新权限
FLUSH PRIVILEGES;

-- 查看用户权限
SHOW GRANTS FOR 'newuser'@'%';

-- 撤销权限
REVOKE ALL PRIVILEGES ON database_name.* FROM 'newuser'@'%';

-- 删除用户
DROP USER 'newuser'@'%';
```

### 2. 数据库备份与恢复
```bash
# 全量备份
mysqldump -u root -p database_name > backup.sql

# 压缩备份
mysqldump -u root -p database_name | gzip > backup.sql.gz

# 恢复数据库
mysql -u root -p database_name < backup.sql

# 只备份表结构
mysqldump -u root -p --no-data database_name > structure.sql

# 只备份数据
mysqldump -u root -p --no-create-info database_name > data.sql
```

### 3. 慢查询分析
```sql
-- 开启慢查询日志
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;  -- 超过2秒的查询记录

-- 查看慢查询配置
SHOW VARIABLES LIKE 'slow_query%';

-- 查看当前连接
SHOW PROCESSLIST;

-- 查看表索引
SHOW INDEX FROM table_name;

-- 分析查询执行计划（面试必考！）
EXPLAIN SELECT * FROM users WHERE username = 'admin';
```

### 4. 常用运维SQL
```sql
-- 查看数据库大小
SELECT table_schema AS '数据库',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS '大小(MB)'
FROM information_schema.tables
GROUP BY table_schema;

-- 查看表行数
SELECT table_name, table_rows 
FROM information_schema.tables 
WHERE table_schema = 'lnmp_db';

-- 查看当前连接数
SHOW STATUS LIKE 'Threads%';
```

---

## 第三部分：Docker 安装与使用

### 1. 安装 Docker（CentOS）
```bash
# 卸载旧版本
sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# 安装依赖
sudo yum install -y yum-utils

# 添加Docker仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
```

### 2. 安装 Docker Compose
```bash
# 下载 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### 3. Docker 常用命令
```bash
# 镜像操作
docker images                    # 查看本地镜像
docker pull nginx:latest         # 拉取镜像
docker rmi image_id              # 删除镜像

# 容器操作
docker ps                        # 查看运行中的容器
docker ps -a                     # 查看所有容器
docker start container_id        # 启动容器
docker stop container_id         # 停止容器
docker restart container_id      # 重启容器
docker rm container_id           # 删除容器
docker logs container_id         # 查看容器日志
docker logs -f container_id      # 实时查看日志
docker exec -it container_id bash  # 进入容器

# Docker Compose 操作
docker-compose up -d             # 后台启动所有服务
docker-compose down              # 停止并删除所有服务
docker-compose ps                # 查看服务状态
docker-compose logs -f           # 实时查看所有日志
docker-compose restart           # 重启所有服务
```

---

## 第四部分：实战操作

### 步骤1：在虚拟机中安装 Docker
按照上面的命令在你的 Linux 虚拟机中安装 Docker 和 Docker Compose。

### 步骤2：克隆/复制项目文件
将 `lnmp-ops-project` 文件夹复制到虚拟机中：
```bash
# 方法1：使用 scp 从Windows复制
scp -r lnmp-ops-project user@虚拟机IP:/home/user/

# 方法2：使用共享文件夹（VMware/VirtualBox）
```

### 步骤3：运行部署脚本
```bash
cd lnmp-ops-project
chmod +x scripts/*.sh
./scripts/deploy.sh
```

### 步骤4：验证部署
```bash
# 检查容器状态
docker-compose ps

# 访问应用
curl http://localhost:8080

# 测试数据库
docker exec lnmp-mysql mysql -uroot -proot123456 -e "SHOW DATABASES;"
```

### 步骤5：运行健康检查
```bash
./scripts/health_check.sh
```

---

## 面试常见问题（Day 1 相关）

### Q1: Linux 中如何查看一个进程占用的端口？
```bash
netstat -tlnp | grep PID
# 或
ss -tlnp | grep PID
# 或
lsof -i :端口号
```

### Q2: 如何查看一个文件的大小？
```bash
ls -lh filename
du -h filename
stat filename
```

### Q3: MySQL 如何备份和恢复？
```bash
# 备份
mysqldump -u root -p database > backup.sql
# 恢复
mysql -u root -p database < backup.sql
```

### Q4: Docker 和虚拟机的区别？
- Docker 是容器化技术，共享宿主机内核，启动快（秒级），资源占用少
- 虚拟机有完整的操作系统，启动慢（分钟级），资源占用多
- Docker 适合微服务部署，虚拟机适合需要完整OS隔离的场景

### Q5: 如何查看 Docker 容器的日志？
```bash
docker logs container_name
docker logs -f container_name  # 实时查看
docker logs --tail 100 container_name  # 查看最后100行
```

---

## 今日作业
1. 在虚拟机中完成 Docker 安装
2. 成功运行 `deploy.sh` 部署 LNMP 环境
3. 能独立使用 `docker-compose` 命令管理服务
4. 练习上面列出的所有 Linux 命令
5. 练习 MySQL 的用户管理和备份恢复操作
