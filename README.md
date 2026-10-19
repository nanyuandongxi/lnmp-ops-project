# LNMP 自动化部署与运维监控平台

## 项目简介
本项目是一个面向运维工程师面试的实战项目，通过 Docker Compose 一键部署 LNMP（Linux + Nginx + MySQL + PHP）环境，并配套完整的自动化运维脚本体系。

## 技术栈
- **Linux**: CentOS 7/Ubuntu 20.04
- **Nginx**: 反向代理与静态资源服务
- **MySQL 8.0**: 关系型数据库
- **PHP 8.0**: 应用运行环境
- **Docker & Docker Compose**: 容器化部署
- **Shell**: 自动化运维脚本

## 项目结构
```
lnmp-ops-project/
├── docker-compose.yml          # Docker Compose 编排文件
├── nginx/
│   ── default.conf            # Nginx 配置文件
├── mysql/
│   └── init.sql                # 数据库初始化脚本
├── scripts/
│   ├── deploy.sh               # 一键部署脚本
│   ├── health_check.sh         # 服务健康检查脚本
│   ├── mysql_backup.sh         # 数据库定时备份脚本
│   ├── log_analyzer.sh         # 日志分析脚本
│   └── monitor.sh              # 系统资源监控脚本
── app/
│   └── index.php               # 测试应用
└── README.md                   # 项目文档
```

## 快速开始

### 1. 环境要求
- Linux 系统（CentOS 7+ / Ubuntu 20.04+）
- Docker 20.10+
- Docker Compose 1.29+

### 2. 一键部署
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

### 3. 验证服务
```bash
# 检查容器状态
docker-compose ps

# 访问应用
curl http://localhost:8080
```

## 运维脚本说明

| 脚本 | 功能 | 使用方式 |
|------|------|----------|
| deploy.sh | 一键部署LNMP环境 | `./scripts/deploy.sh` |
| health_check.sh | 检查所有服务健康状态 | `./scripts/health_check.sh` |
| mysql_backup.sh | 定时备份MySQL数据库 | `./scripts/mysql_backup.sh` |
| log_analyzer.sh | 分析Nginx访问日志 | `./scripts/log_analyzer.sh` |
| monitor.sh | 监控系统资源使用情况 | `./scripts/monitor.sh` |

## 面试亮点
1. **容器化部署**: 使用 Docker Compose 实现一键部署，体现现代化运维能力
2. **自动化运维**: 5个运维脚本覆盖部署、监控、备份、日志分析全流程
3. **安全加固**: 数据库密码加密、权限最小化、防火墙配置
4. **文档规范**: 完整的运维文档和操作手册
