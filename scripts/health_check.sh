#!/bin/bash
###############################################################################
# 服务健康检查脚本
# 功能: 检查所有LNMP服务的健康状态，生成健康报告
# 用法: ./health_check.sh
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目目录
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE="$PROJECT_DIR/logs/health_report_$(date +%Y%m%d_%H%M%S).txt"

# 检查结果计数
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

###############################################################################
# 检查函数
###############################################################################
check_item() {
    local name="$1"
    local result="$2"  # 0=成功, 1=失败
    local detail="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$result" -eq 0 ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo -e "  ${GREEN}✓${NC} $name - $detail"
        echo "  [PASS] $name - $detail" >> "$REPORT_FILE"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo -e "  ${RED}✗${NC} $name - $detail"
        echo "  [FAIL] $name - $detail" >> "$REPORT_FILE"
    fi
}

###############################################################################
# 1. 检查 Docker 服务
###############################################################################
check_docker() {
    echo -e "\n${BLUE}=== Docker 服务检查 ===${NC}"
    echo "=== Docker 服务检查 ===" >> "$REPORT_FILE"
    
    # 检查 Docker 是否运行
    if docker info &> /dev/null; then
        check_item "Docker 守护进程" 0 "运行正常"
    else
        check_item "Docker 守护进程" 1 "未运行"
        return
    fi
    
    # 检查 Docker 磁盘使用
    DISK_USAGE=$(docker system df 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/%//')
    if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -lt 90 ]; then
        check_item "Docker 磁盘使用" 0 "${DISK_USAGE}%"
    else
        check_item "Docker 磁盘使用" 1 "${DISK_USAGE:-未知}%"
    fi
}

###############################################################################
# 2. 检查容器状态
###############################################################################
check_containers() {
    echo -e "\n${BLUE}=== 容器状态检查 ===${NC}"
    echo "=== 容器状态检查 ===" >> "$REPORT_FILE"
    
    cd "$PROJECT_DIR"
    
    # 获取所有服务
    SERVICES=$(docker-compose ps --services 2>/dev/null)
    
    if [ -z "$SERVICES" ]; then
        check_item "容器列表" 1 "无法获取服务列表"
        return
    fi
    
    for service in $SERVICES; do
        STATUS=$(docker-compose ps "$service" 2>/dev/null | tail -1 | awk '{print $3}')
        if echo "$STATUS" | grep -qi "up\|running"; then
            check_item "容器 $service" 0 "运行中"
        else
            check_item "容器 $service" 1 "状态: $STATUS"
        fi
    done
}

###############################################################################
# 3. 检查 Nginx
###############################################################################
check_nginx() {
    echo -e "\n${BLUE}=== Nginx 检查 ===${NC}"
    echo "=== Nginx 检查 ===" >> "$REPORT_FILE"
    
    # HTTP 响应检查
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ]; then
        check_item "Nginx HTTP响应" 0 "状态码: $HTTP_CODE"
    else
        check_item "Nginx HTTP响应" 1 "状态码: ${HTTP_CODE:-无响应}"
    fi
    
    # 健康检查端点
    HEALTH=$(curl -s http://localhost:8080/health 2>/dev/null)
    if [ "$HEALTH" = "OK" ]; then
        check_item "Nginx 健康端点" 0 "响应正常"
    else
        check_item "Nginx 健康端点" 1 "响应: ${HEALTH:-无响应}"
    fi
    
    # 检查错误日志
    ERROR_LOG="$PROJECT_DIR/logs/nginx/error.log"
    if [ -f "$ERROR_LOG" ]; then
        ERROR_COUNT=$(tail -100 "$ERROR_LOG" 2>/dev/null | grep -c "error\|crit" || echo "0")
        if [ "$ERROR_COUNT" -eq 0 ]; then
            check_item "Nginx 错误日志" 0 "最近100行无错误"
        else
            check_item "Nginx 错误日志" 1 "发现 $ERROR_COUNT 条错误"
        fi
    fi
}

###############################################################################
# 4. 检查 MySQL
###############################################################################
check_mysql() {
    echo -e "\n${BLUE}=== MySQL 检查 ===${NC}"
    echo "=== MySQL 检查 ===" >> "$REPORT_FILE"
    
    # 检查 MySQL 容器
    if docker exec lnmp-mysql mysqladmin ping -h localhost -uroot -proot123456 2>/dev/null | grep -q "alive"; then
        check_item "MySQL 连接" 0 "服务正常"
    else
        check_item "MySQL 连接" 1 "无法连接"
        return
    fi
    
    # 检查数据库是否存在
    if docker exec lnmp-mysql mysql -uroot -proot123456 -e "USE lnmp_db" 2>/dev/null; then
        check_item "数据库 lnmp_db" 0 "存在"
    else
        check_item "数据库 lnmp_db" 1 "不存在"
    fi
    
    # 检查表数量
    TABLE_COUNT=$(docker exec lnmp-mysql mysql -uroot -proot123456 -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='lnmp_db'" 2>/dev/null)
    if [ -n "$TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
        check_item "数据表数量" 0 "$TABLE_COUNT 张表"
    else
        check_item "数据表数量" 1 "无表"
    fi
    
    # 检查连接数
    CONNECTIONS=$(docker exec lnmp-mysql mysql -uroot -proot123456 -N -e "SHOW STATUS LIKE 'Threads_connected'" 2>/dev/null | awk '{print $2}')
    if [ -n "$CONNECTIONS" ]; then
        check_item "MySQL 连接数" 0 "当前: $CONNECTIONS"
    fi
}

###############################################################################
# 5. 检查系统资源
###############################################################################
check_system_resources() {
    echo -e "\n${BLUE}=== 系统资源检查 ===${NC}"
    echo "=== 系统资源检查 ===" >> "$REPORT_FILE"
    
    # CPU 使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [ -n "$CPU_USAGE" ]; then
        CPU_INT=${CPU_USAGE%.*}
        if [ "$CPU_INT" -lt 80 ]; then
            check_item "CPU 使用率" 0 "${CPU_USAGE}%"
        else
            check_item "CPU 使用率" 1 "${CPU_USAGE}% (过高)"
        fi
    fi
    
    # 内存使用率
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    if [ -n "$MEM_USAGE" ]; then
        MEM_INT=${MEM_USAGE%.*}
        if [ "$MEM_INT" -lt 80 ]; then
            check_item "内存使用率" 0 "${MEM_USAGE}%"
        else
            check_item "内存使用率" 1 "${MEM_USAGE}% (过高)"
        fi
    fi
    
    # 磁盘使用率
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ -n "$DISK_USAGE" ]; then
        if [ "$DISK_USAGE" -lt 80 ]; then
            check_item "磁盘使用率" 0 "${DISK_USAGE}%"
        else
            check_item "磁盘使用率" 1 "${DISK_USAGE}% (过高)"
        fi
    fi
    
    # 系统运行时间
    UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    check_item "系统运行时间" 0 "$UPTIME"
}

###############################################################################
# 主函数
###############################################################################
main() {
    echo "=============================================="
    echo "  LNMP 服务健康检查"
    echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    
    # 创建报告文件
    mkdir -p "$PROJECT_DIR/logs"
    echo "LNMP 健康检查报告" > "$REPORT_FILE"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    
    check_docker
    check_containers
    check_nginx
    check_mysql
    check_system_resources
    
    # 输出总结
    echo -e "\n=============================================="
    echo -e "  检查总结: 总计 ${TOTAL_CHECKS} 项, ${GREEN}通过 ${PASSED_CHECKS}${NC}, ${RED}失败 ${FAILED_CHECKS}${NC}"
    echo "  详细报告: $REPORT_FILE"
    echo "=============================================="
    
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        exit 1
    fi
}

main "$@"
