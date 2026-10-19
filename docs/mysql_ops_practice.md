# MySQL 运维实操指南（基于 LNMP 项目环境）

> 前置条件：LNMP 项目已通过 Docker Compose 正常运行
> 所有操作都在你的 Ubuntu 虚拟机中完成

---

## 准备工作：进入 MySQL

```bash
# 方式1：从宿主机直接进入 MySQL 容器
docker exec -it lnmp-mysql mysql -uroot -proot123456

# 方式2：从宿主机直接执行单条 SQL
docker exec lnmp-mysql mysql -uroot -proot123456 -e "SHOW DATABASES;"

# 方式3：进入容器的 bash 后再连接
docker exec -it lnmp-mysql bash
mysql -uroot -proot123456
```

进入后你会看到 `mysql>` 提示符，后面的命令都在这个提示符下执行。

---

## 第一章：数据库巡检（运维日常第一件事）

### 1.1 查看服务器状态

```sql
-- 查看 MySQL 版本
SELECT VERSION();

-- 查看运行时间
SHOW STATUS LIKE 'Uptime';

-- 查看当前连接数（面试常问：怎么知道数据库负载？）
SHOW STATUS LIKE 'Threads%';
-- Threads_connected  : 当前连接数
-- Threads_running    : 活跃连接数（正在执行查询的）
-- 如果 running 接近 connected，说明数据库很忙

-- 查看最大允许连接数
SHOW VARIABLES LIKE 'max_connections';

-- 查看当前所有连接详情（谁在连？在干什么？）
SHOW PROCESSLIST;
-- 重点看 State 列：
--   executing    = 正在执行查询
--   Sending data = 正在发送结果
--   Waiting for table lock = 等锁（可能有问题）
--   Sleep      = 空闲连接
```

### 1.2 查看数据库和表

```sql
-- 查看所有数据库
SHOW DATABASES;

-- 查看数据库详情（字符集、排序规则）
SHOW CREATE DATABASE lnmp_db;

-- 切换到项目数据库
USE lnmp_db;

-- 查看所有表
SHOW TABLES;

-- 查看表结构（面试：怎么快速看一个表的字段？）
DESC users;
-- 或者完整写法
DESCRIBE users;

-- 查看表的创建语句（能看到引擎、字符集、注释）
SHOW CREATE TABLE users;

-- 查看表状态（行数、大小、引擎）
SHOW TABLE STATUS LIKE 'users';
-- 重点看：
--   Rows       = 估算行数
--   Data_length = 数据大小（字节）
--   Engine     = 存储引擎
```

### 1.3 查看数据库大小

```sql
-- 各数据库大小
SELECT table_schema AS '数据库',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS '大小(MB)'
FROM information_schema.tables
GROUP BY table_schema
ORDER BY SUM(data_length + index_length) DESC;

-- lnmp_db 中各表大小
SELECT table_name AS '表名',
       table_rows AS '行数',
       ROUND((data_length + index_length) / 1024, 2) AS '大小(KB)'
FROM information_schema.tables
WHERE table_schema = 'lnmp_db'
ORDER BY (data_length + index_length) DESC;
```

**动手练习：** 执行上面的命令，看看你的 lnmp_db 目前有多大。

---

## 第二章：用户与权限管理（安全核心）

### 2.1 查看现有用户

```sql
-- 查看所有用户
SELECT user, host FROM mysql.user;

-- 查看用户详情
SELECT user, host, account_locked, password_expired FROM mysql.user;
```

### 2.2 创建用户（运维日常）

```sql
-- 创建应用用户（只能从 localhost 连接）
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'App@2026!';

-- 创建应用用户（可以从任意主机连接，Docker 环境常用）
CREATE USER 'app_user'@'%' IDENTIFIED BY 'App@2026!';

-- 创建只读用户（给监控系统用）
CREATE USER 'readonly'@'%' IDENTIFIED BY 'Read@2026!';

-- 创建备份专用用户
CREATE USER 'backup'@'%' IDENTIFIED BY 'Backup@2026!';
```

### 2.3 权限分配（面试高频）

```sql
-- 给应用用户完整的应用权限（增删改查 + 创建临时表）
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE TEMPORARY TABLES 
ON lnmp_db.* TO 'app_user'@'%';

-- 给只读用户只有查询权限
GRANT SELECT ON lnmp_db.* TO 'readonly'@'%';

-- 给备份用户需要的权限
GRANT SELECT, SHOW VIEW, LOCK TABLES, RELOAD, REPLICATION CLIENT 
ON *.* TO 'backup'@'%';

-- 刷新权限（修改权限后必须执行）
FLUSH PRIVILEGES;
```

### 2.4 查看和验证权限

```sql
-- 查看某用户的权限
SHOW GRANTS FOR 'app_user'@'%';
SHOW GRANTS FOR 'readonly'@'%';
SHOW GRANTS FOR 'backup'@'%';

-- 查看当前登录用户的权限
SHOW GRANTS;
```

### 2.5 权限回收与用户删除

```sql
-- 撤销用户的 UPDATE 权限
REVOKE UPDATE ON lnmp_db.* FROM 'app_user'@'%';

-- 验证撤销结果
SHOW GRANTS FOR 'app_user'@'%';

-- 锁定用户（临时禁用，不删除）
ALTER USER 'app_user'@'%' ACCOUNT LOCK;

-- 解锁用户
ALTER USER 'app_user'@'%' ACCOUNT UNLOCK;

-- 删除用户
DROP USER 'readonly'@'%';
```

### 2.6 密码管理

```sql
-- 修改用户密码
ALTER USER 'app_user'@'%' IDENTIFIED BY 'NewApp@2026!';

-- 修改 root 密码
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NewRoot@2026!';

-- 设置密码过期策略
ALTER USER 'app_user'@'%' PASSWORD EXPIRE INTERVAL 90 DAY;

-- 手动让密码立即过期（强制用户改密码）
ALTER USER 'app_user'@'%' PASSWORD EXPIRE;
```

> **面试要点：** 权限管理遵循"最小权限原则"——只给用户完成工作所需的最少权限。

---

## 第三章：数据操作实战

### 3.1 查看现有数据

```sql
USE lnmp_db;

-- 查看所有用户
SELECT * FROM users;

-- 查看所有系统日志
SELECT * FROM system_logs;

-- 条件查询
SELECT * FROM users WHERE status = 1;
SELECT * FROM system_logs WHERE level = 'ERROR';

-- 统计查询
SELECT COUNT(*) AS '总用户数' FROM users;
SELECT COUNT(*) AS '活跃用户数' FROM users WHERE status = 1;
SELECT level, COUNT(*) AS '数量' FROM system_logs GROUP BY level;
```

### 3.2 插入数据

```sql
-- 插入单条
INSERT INTO users (username, email, status) 
VALUES ('zhangsan', 'zhangsan@example.com', 1);

-- 插入多条
INSERT INTO users (username, email, status) VALUES
('lisi', 'lisi@example.com', 1),
('wangwu', 'wangwu@example.com', 1),
('zhaoliu', 'zhaoliu@example.com', 0);

-- 插入日志
INSERT INTO system_logs (level, module, message) VALUES
('INFO', 'auth', 'User zhangsan logged in'),
('WARN', 'auth', 'Failed login attempt for user hacker'),
('ERROR', 'db', 'Connection timeout after 30s');
```

### 3.3 更新数据

```sql
-- 更新单条
UPDATE users SET status = 0 WHERE username = 'demo';

-- 更新多条
UPDATE users SET email = 'new_email@example.com' WHERE username = 'lisi';

-- 注意：不带 WHERE 会更新所有行！（运维大忌）
-- 安全做法：先用 SELECT 确认要更新的行
SELECT * FROM users WHERE username = 'lisi';  -- 先确认
UPDATE users SET email = 'correct@example.com' WHERE username = 'lisi';  -- 再更新
```

### 3.4 删除数据

```sql
-- 删除单条
DELETE FROM system_logs WHERE level = 'INFO' AND module = 'system';

-- 清空表（保留表结构，比 DELETE 快）
-- TRUNCATE TABLE system_logs;  -- 先不执行，后面会用到

-- 注意：不带 WHERE 会删除所有行！（运维大忌中的大忌）
```

---

## 第四章：索引与查询优化（面试必考）

### 4.1 查看现有索引

```sql
-- 查看 users 表的索引
SHOW INDEX FROM users;

-- 查看 system_logs 表的索引
SHOW INDEX FROM system_logs;

-- 用 EXPLAIN 分析查询（面试必考！）
EXPLAIN SELECT * FROM users WHERE username = 'admin';
```

**EXPLAIN 重点看：**
- `type`：访问类型，从好到差：system > const > eq_ref > ref > range > index > ALL
- `key`：实际使用的索引（NULL 表示没用到索引！）
- `rows`：扫描行数（越少越好）
- `Extra`：Using filesort（需要优化）、Using index（覆盖索引，好）

### 4.2 对比：有索引 vs 没索引

```sql
-- 有索引的查询（username 字段有索引 idx_username）
EXPLAIN SELECT * FROM users WHERE username = 'admin';
-- 看 type=ref, key=idx_username, rows=1 → 很快

-- 没索引的查询（email 虽然有 idx_email，我们试试别的字段）
EXPLAIN SELECT * FROM system_logs WHERE message LIKE '%error%';
-- 看 type=ALL, key=NULL → 全表扫描，数据量大时会很慢
```

### 4.3 创建和管理索引

```sql
-- 创建普通索引
CREATE INDEX idx_status ON users(status);

-- 创建组合索引
CREATE INDEX idx_level_created ON system_logs(level, created_at);

-- 查看创建后的效果
EXPLAIN SELECT * FROM users WHERE status = 1;
EXPLAIN SELECT * FROM system_logs WHERE level = 'ERROR' AND created_at > '2026-01-01';

-- 删除索引
DROP INDEX idx_status ON users;
```

### 4.4 慢查询日志（运维排障利器）

```sql
-- 查看慢查询配置
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';

-- 开启慢查询日志（如果没开）
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;  -- 超过1秒的记录

-- 查看慢查询数量
SHOW GLOBAL STATUS LIKE 'Slow_queries';

-- 模拟一个慢查询（在 system_logs 上做无索引的大范围扫描）
SELECT * FROM system_logs WHERE message LIKE '%a%' ORDER BY created_at;
```

---

## 第五章：事务与锁（运维必须理解）

### 5.1 事务基础

```sql
-- 查看当前事务隔离级别
SELECT @@transaction_isolation;
-- MySQL 8.0 默认：REPEATABLE-READ

-- 事务的四个隔离级别（面试常考）
-- READ UNCOMMITTED  → 可能脏读
-- READ COMMITTED    → 避免脏读，可能不可重复读
-- REPEATABLE READ   → 避免不可重复读，可能幻读（MySQL 默认）
-- SERIALIZABLE      → 串行化，最安全但最慢
```

### 5.2 事务操作

```sql
-- 开始事务
START TRANSACTION;

-- 查看当前 users 表数据
SELECT * FROM users;

-- 执行修改（此时还没提交）
INSERT INTO users (username, email, status) VALUES ('tx_test', 'tx@test.com', 1);

-- 在另一个连接中查看（开一个新的 docker exec）
-- 新连接看不到 tx_test，因为事务还没提交

-- 回滚（撤销修改）
ROLLBACK;
-- 验证：tx_test 不存在了
SELECT * FROM users WHERE username = 'tx_test';

-- 再次插入并提交
START TRANSACTION;
INSERT INTO users (username, email, status) VALUES ('tx_committed', 'tx2@test.com', 1);
COMMIT;
-- 验证：数据已保存
SELECT * FROM users WHERE username = 'tx_committed';
```

### 5.3 查看和排查锁

```sql
-- 查看当前锁等待（MySQL 8.0）
SELECT * FROM performance_schema.data_locks;

-- 查看锁等待关系
SELECT * FROM performance_schema.data_lock_waits;

-- 查看当前活跃事务
SELECT * FROM information_schema.innodb_trx;

-- 如果有事务卡住了，可以杀掉
-- KILL 进程ID;
```

---

## 第六章：MySQL 备份与恢复（运维核心职责）

### 6.1 全量备份与恢复

```bash
# 在宿主机执行（不需要进入容器）

# 1. 全量备份
docker exec lnmp-mysql mysqldump -uroot -proot123456 \
  --single-transaction \
  --routines \
  --triggers \
  lnmp_db > /tmp/lnmp_db_backup.sql

# 2. 压缩备份（节省空间）
docker exec lnmp-mysql mysqldump -uroot -proot123456 \
  --single-transaction \
  lnmp_db | gzip > /tmp/lnmp_db_backup.sql.gz

# 3. 只备份表结构
docker exec lnmp-mysql mysqldump -uroot -proot123456 \
  --no-data \
  lnmp_db > /tmp/lnmp_db_structure.sql

# 4. 只备份数据（不含建表语句）
docker exec lnmp-mysql mysqldump -uroot -proot123456 \
  --no-create-info \
  lnmp_db > /tmp/lnmp_db_data.sql
```

### 6.2 模拟灾难恢复

```bash
# 1. 先备份
docker exec lnmp-mysql mysqldump -uroot -proot123456 \
  --single-transaction lnmp_db > /tmp/rescue_backup.sql

# 2. 模拟误操作：删除 users 表
docker exec lnmp-mysql mysql -uroot -proot123456 -e "USE lnmp_db; DROP TABLE users;"

# 3. 确认数据没了
docker exec lnmp-mysql mysql -uroot -proot123456 -e "USE lnmp_db; SHOW TABLES;"

# 4. 从备份恢复
docker exec -i lnmp-mysql mysql -uroot -proot123456 < /tmp/rescue_backup.sql

# 5. 确认恢复成功
docker exec lnmp-mysql mysql -uroot -proot123456 -e "USE lnmp_db; SHOW TABLES;"
docker exec lnmp-mysql mysql -uroot -proot123456 -e "USE lnmp_db; SELECT * FROM users;"
```

### 6.3 用项目脚本备份

```bash
# 进入项目目录
cd ~/lnmp-ops-project

# 全量备份
./scripts/mysql_backup.sh full

# 查看备份文件
ls -lh backups/mysql/

# 查看备份日志
cat logs/mysql_backup.log
```

---

## 第七章：MySQL 常用配置参数

### 7.1 查看关键配置

```sql
-- 查看最大连接数
SHOW VARIABLES LIKE 'max_connections';

-- 查看 InnoDB 缓冲池大小（最重要的性能参数）
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- 查看日志相关配置
SHOW VARIABLES LIKE '%log%';

-- 查看字符集配置
SHOW VARIABLES LIKE 'character_set%';
SHOW VARIABLES LIKE 'collation%';

-- 查看超时配置
SHOW VARIABLES LIKE '%timeout%';
-- wait_timeout = 非交互连接等待超时
-- connect_timeout = 连接超时
```

### 7.2 动态调整参数（不需要重启）

```sql
-- 调整最大连接数
SET GLOBAL max_connections = 200;

-- 调整慢查询阈值
SET GLOBAL long_query_time = 1;
```

### 7.3 查看 MySQL 运行统计

```sql
-- 查看 MySQL 启动以来的统计
SHOW GLOBAL STATUS;

-- 常用统计项
SHOW GLOBAL STATUS LIKE 'Questions';          -- 执行的查询总数
SHOW GLOBAL STATUS LIKE 'Com_select';         -- SELECT 次数
SHOW GLOBAL STATUS LIKE 'Com_insert';         -- INSERT 次数
SHOW GLOBAL STATUS LIKE 'Com_update';         -- UPDATE 次数
SHOW GLOBAL STATUS LIKE 'Com_delete';         -- DELETE 次数
SHOW GLOBAL STATUS LIKE 'Connections';        -- 总连接次数
SHOW GLOBAL STATUS LIKE 'Aborted_connects';   -- 中断的连接数（多了可能有问题）
SHOW GLOBAL STATUS LIKE 'Slow_queries';       -- 慢查询数量
```

---

## 第八章：运维排障实战（面试场景题）

### 场景1：数据库连接不上

```bash
# 排查步骤：

# 1. 检查容器是否运行
docker ps | grep mysql

# 2. 检查端口是否监听
ss -tlnp | grep 3306

# 3. 检查 MySQL 错误日志
docker logs lnmp-mysql --tail 50

# 4. 进入容器尝试本地连接
docker exec -it lnmp-mysql mysql -uroot -proot123456

# 5. 检查连接数是否满了
docker exec lnmp-mysql mysql -uroot -proot123456 -e "SHOW STATUS LIKE 'Threads%';"

# 6. 检查磁盘空间（磁盘满会导致 MySQL 异常）
df -h
```

### 场景2：查询很慢

```sql
-- 排查步骤：

-- 1. 查看当前在执行的查询
SHOW PROCESSLIST;

-- 2. 找到慢查询的 ID，杀掉它
KILL 查询ID;

-- 3. 分析慢查询
EXPLAIN SELECT ...;  -- 把慢的 SQL 放进来分析

-- 4. 检查是否缺索引
SHOW INDEX FROM 表名;

-- 5. 检查表数据量
SELECT COUNT(*) FROM 表名;

-- 6. 查看慢查询日志
-- 在容器内查看
-- docker exec lnmp-mysql cat /var/lib/mysql/$(hostname)-slow.log
```

### 场景3：磁盘空间不足

```bash
# 排查步骤：

# 1. 查看磁盘使用
df -h

# 2. 查看 MySQL 数据目录大小
docker exec lnmp-mysql du -sh /var/lib/mysql/

# 3. 查看 binlog 大小
docker exec lnmp-mysql mysql -uroot -proot123456 -e "SHOW BINARY LOGS;"

# 4. 清理 binlog（释放空间）
docker exec lnmp-mysql mysql -uroot -proot123456 -e "PURGE BINARY LOGS BEFORE NOW();"

# 5. 清理旧备份
find /path/to/backups -name "*.gz" -mtime +30 -delete
```

---

## 第九章：面试高频 MySQL 问题速答

### Q1: MySQL 的存储引擎 InnoDB 和 MyISAM 的区别？
- InnoDB：支持事务、支持行锁、支持外键、崩溃恢复好（默认引擎）
- MyISAM：不支持事务、表锁、不支持外键、速度快但不安全
- 运维建议：生产环境统一用 InnoDB

### Q2: 什么是索引？索引的优缺点？
- 索引是帮助查询快速定位数据的数据结构（B+树）
- 优点：加速查询
- 缺点：占用磁盘空间、降低写入速度（每次 INSERT/UPDATE 要更新索引）
- 建议：为 WHERE、JOIN、ORDER BY 的字段建索引

### Q3: 如何排查慢查询？
1. 开启慢查询日志：`SET GLOBAL slow_query_log = 'ON';`
2. 用 `SHOW PROCESSLIST` 看当前正在执行的查询
3. 用 `EXPLAIN` 分析查询执行计划
4. 检查是否缺少索引
5. 检查表数据量是否需要分表

### Q4: mysqldump 的 --single-transaction 参数有什么用？
- 在备份开始时开启一个一致性快照事务
- 保证 InnoDB 表在备份过程中数据一致
- 不会锁表，不影响正常的读写操作
- 只对 InnoDB 引擎有效

### Q5: 如何保证数据库安全？
1. 使用强密码，定期更换
2. 最小权限原则，不用 root 连接应用
3. 限制用户来源 IP（host 字段）
4. 关闭远程 root 登录
5. 定期备份，验证备份可恢复
6. 开启审计日志

### Q6: MySQL 主从复制了解吗？
- 主库将变更写入 binlog
- 从库读取主库的 binlog 并回放
- 用于读写分离、数据备份、高可用
- 运维需要监控复制延迟和状态

---

## 今日练习清单

1. **进入 MySQL**：用三种方式进入 MySQL 命令行
2. **数据库巡检**：查看版本、运行时间、连接数、数据库大小
3. **用户管理**：创建 3 个不同权限的用户，验证权限，再删除
4. **数据操作**：向 users 表插入 5 条数据，查询、更新、删除
5. **索引分析**：用 EXPLAIN 分析 3 条不同的查询
6. **备份恢复**：完整做一次备份 → 删表 → 恢复的流程
7. **运行项目脚本**：执行 `mysql_backup.sh full`，查看备份文件
8. **排障练习**：模拟连接失败，按步骤排查

---

## 速查卡片

```
┌─────────────────────────────────────────────────┐
│            MySQL 运维速查                         │
├─────────────────────────────────────────────────┤
│ 进入容器    docker exec -it lnmp-mysql mysql -uroot -p │
│ 查看连接    SHOW PROCESSLIST;                     │
│ 查看权限    SHOW GRANTS FOR 'user'@'host';        │
│ 分析查询    EXPLAIN SELECT ...;                   │
│ 备份数据库  mysqldump --single-transaction db > b.sql │
│ 恢复数据库  mysql db < backup.sql                  │
│ 查看慢查询  SHOW GLOBAL STATUS LIKE 'Slow_queries';│
│ 杀掉进程    KILL 进程ID;                           │
│ 查看大小    SHOW TABLE STATUS;                     │
└─────────────────────────────────────────────────┘
```
