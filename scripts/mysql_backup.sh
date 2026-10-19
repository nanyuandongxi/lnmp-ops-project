#!/bin/bash
###############################################################################
# MySQL 数据库定时备份脚本
# 功能: 备份MySQL数据库，支持全量备份和增量备份，自动清理旧备份
# 用法: ./mysql_backup.sh [full|incremental]
# 定时任务: 0 2 * * * /path/to/mysql_backup.sh full
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置项
MYSQL_CONTAINER="lnmp-mysql"
MYSQL_USER="root"
MYSQL_PASSWORD="root123456"
MYSQL_DATABASE="lnmp_db"
BACKUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/backups/mysql"
BACKUP_RETENTION_DAYS=30  # 保留天数
BACKUP_TYPE="${1:-full}"  # 默认全量备份
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${MYSQL_DATABASE}_${BACKUP_TYPE}_${TIMESTAMP}.sql.gz"
LOG_FILE="$(cd "$(dirname "$0")/.." && pwd)/logs/mysql_backup.log"

###############################################################################
# 日志函数
###############################################################################
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

###############################################################################
# 初始化
###############################################################################
init() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "=========================================="
    log "INFO" "开始 MySQL 备份"
    log "INFO" "备份类型: $BACKUP_TYPE"
    log "INFO" "备份文件: $BACKUP_FILE"
    log "INFO" "=========================================="
}

###############################################################################
# 检查 MySQL 连接
###############################################################################
check_mysql() {
    log "INFO" "检查 MySQL 连接..."
    
    if docker exec "$MYSQL_CONTAINER" mysqladmin ping -h localhost -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" 2>/dev/null | grep -q "alive"; then
        log "INFO" "MySQL 连接正常"
        return 0
    else
        log "ERROR" "MySQL 连接失败"
        return 1
    fi
}

###############################################################################
# 全量备份
###############################################################################
full_backup() {
    log "INFO" "开始全量备份..."
    
    # 记录备份开始时间
    START_TIME=$(date +%s)
    
    # 执行备份
    docker exec "$MYSQL_CONTAINER" mysqldump \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --databases "$MYSQL_DATABASE" \
        2>/dev/null | gzip > "$BACKUP_FILE"
    
    # 记录备份结束时间
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # 检查备份文件
    if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
        FILE_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log "INFO" "全量备份完成"
        log "INFO" "备份文件: $BACKUP_FILE"
        log "INFO" "文件大小: $FILE_SIZE"
        log "INFO" "耗时: ${DURATION}秒"
        
        # 验证备份文件
        if gzip -t "$BACKUP_FILE" 2>/dev/null; then
            log "INFO" "备份文件验证通过"
        else
            log "ERROR" "备份文件验证失败"
            return 1
        fi
    else
        log "ERROR" "备份文件创建失败"
        return 1
    fi
}

###############################################################################
# 增量备份（基于binlog）
###############################################################################
incremental_backup() {
    log "INFO" "开始增量备份..."
    
    # 刷新binlog
    docker exec "$MYSQL_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "FLUSH BINARY LOGS;" 2>/dev/null
    
    # 获取binlog文件列表
    BINLOG_FILES=$(docker exec "$MYSQL_CONTAINER" mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -N -e "SHOW BINARY LOGS;" 2>/dev/null | awk '{print $1}')
    
    for binlog in $BINLOG_FILES; do
        BINLOG_BACKUP="$BACKUP_DIR/binlog_${TIMESTAMP}_${binlog}.gz"
        docker exec "$MYSQL_CONTAINER" cat "/var/lib/mysql/$binlog" 2>/dev/null | gzip > "$BINLOG_BACKUP"
        log "INFO" "备份 binlog: $binlog -> $BINLOG_BACKUP"
    done
    
    log "INFO" "增量备份完成"
}

###############################################################################
# 清理旧备份
###############################################################################
cleanup_old_backups() {
    log "INFO" "清理 ${BACKUP_RETENTION_DAYS} 天前的旧备份..."
    
    # 查找并删除旧备份文件
    OLD_FILES=$(find "$BACKUP_DIR" -name "*.sql.gz" -o -name "binlog_*.gz" -mtime +$BACKUP_RETENTION_DAYS 2>/dev/null)
    
    if [ -n "$OLD_FILES" ]; then
        echo "$OLD_FILES" | while read file; do
            rm -f "$file"
            log "INFO" "删除旧备份: $file"
        done
    else
        log "INFO" "没有需要清理的旧备份"
    fi
    
    # 统计当前备份数量
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.gz" | wc -l)
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    log "INFO" "当前备份数量: $BACKUP_COUNT, 总大小: $TOTAL_SIZE"
}

###############################################################################
# 生成备份报告
###############################################################################
generate_report() {
    local report_file="$(cd "$(dirname "$0")/.." && pwd)/logs/backup_report_$(date +%Y%m%d).txt"
    
    cat > "$report_file" << EOF
MySQL 备份报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S')
========================================

备份目录: $BACKUP_DIR
保留策略: ${BACKUP_RETENTION_DAYS} 天

最近备份文件:
$(ls -lh "$BACKUP_DIR"/*.gz 2>/dev/null | tail -10)

磁盘使用情况:
$(df -h "$BACKUP_DIR" | tail -1)
EOF
    
    log "INFO" "备份报告已生成: $report_file"
}

###############################################################################
# 主函数
###############################################################################
main() {
    init
    
    # 检查 MySQL 连接
    if ! check_mysql; then
        log "ERROR" "MySQL 连接检查失败，退出备份"
        exit 1
    fi
    
    # 执行备份
    case "$BACKUP_TYPE" in
        full)
            full_backup
            ;;
        incremental)
            incremental_backup
            ;;
        *)
            log "ERROR" "未知的备份类型: $BACKUP_TYPE"
            log "INFO" "用法: $0 [full|incremental]"
            exit 1
            ;;
    esac
    
    # 清理旧备份
    cleanup_old_backups
    
    # 生成报告
    generate_report
    
    log "INFO" "=========================================="
    log "INFO" "备份任务完成"
    log "INFO" "=========================================="
}

main "$@"
