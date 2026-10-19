#!/bin/bash
###############################################################################
# Nginx 日志分析脚本
# 功能: 分析Nginx访问日志，统计PV/UV、状态码、热门URL、异常IP等
# 用法: ./log_analyzer.sh [日志文件路径]
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目目录
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${1:-$PROJECT_DIR/logs/nginx/access.log}"
REPORT_DIR="$PROJECT_DIR/logs/reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

###############################################################################
# 检查日志文件
###############################################################################
check_log_file() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${RED}错误: 日志文件不存在: $LOG_FILE${NC}"
        echo "用法: $0 [日志文件路径]"
        echo "默认路径: $PROJECT_DIR/logs/nginx/access.log"
        exit 1
    fi
    
    if [ ! -s "$LOG_FILE" ]; then
        echo -e "${YELLOW}警告: 日志文件为空${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}分析日志文件: $LOG_FILE${NC}"
    echo -e "${BLUE}文件大小: $(du -h "$LOG_FILE" | cut -f1)${NC}"
    echo -e "${BLUE}日志行数: $(wc -l < "$LOG_FILE")${NC}"
    echo ""
}

###############################################################################
# 1. 基础统计
###############################################################################
basic_stats() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  1. 基础统计${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # 总请求数 (PV)
    TOTAL_REQUESTS=$(wc -l < "$LOG_FILE")
    echo -e "  总请求数 (PV): ${GREEN}${TOTAL_REQUESTS}${NC}"
    
    # 独立IP数 (UV)
    UNIQUE_IPS=$(awk '{print $1}' "$LOG_FILE" | sort -u | wc -l)
    echo -e "  独立IP数 (UV): ${GREEN}${UNIQUE_IPS}${NC}"
    
    # 总流量
    TOTAL_BYTES=$(awk '{sum += $10} END {print sum}' "$LOG_FILE")
    if [ "$TOTAL_BYTES" -gt 1073741824 ]; then
        TOTAL_TRAFFIC=$(echo "scale=2; $TOTAL_BYTES/1073741824" | bc)
        echo -e "  总流量: ${GREEN}${TOTAL_TRAFFIC} GB${NC}"
    elif [ "$TOTAL_BYTES" -gt 1048576 ]; then
        TOTAL_TRAFFIC=$(echo "scale=2; $TOTAL_BYTES/1048576" | bc)
        echo -e "  总流量: ${GREEN}${TOTAL_TRAFFIC} MB${NC}"
    else
        echo -e "  总流量: ${GREEN}${TOTAL_BYTES} Bytes${NC}"
    fi
    
    echo ""
}

###############################################################################
# 2. HTTP 状态码分布
###############################################################################
status_code_stats() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  2. HTTP 状态码分布${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn | while read count code; do
        case $code in
            2*) color="$GREEN" ;;
            3*) color="$BLUE" ;;
            4*) color="$YELLOW" ;;
            5*) color="$RED" ;;
            *)  color="$NC" ;;
        esac
        printf "  ${color}%-6s${NC} %s 次 (%.1f%%)\n" "$code" "$count" "$(echo "scale=1; $count*100/$TOTAL_REQUESTS" | bc)"
    done
    
    echo ""
}

###############################################################################
# 3. 热门 URL Top 10
###############################################################################
top_urls() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  3. 热门 URL Top 10${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10 | while read count url; do
        printf "  %-50s %s 次\n" "$url" "$count"
    done
    
    echo ""
}

###############################################################################
# 4. 热门 IP Top 10
###############################################################################
top_ips() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  4. 访问IP Top 10${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10 | while read count ip; do
        printf "  %-20s %s 次\n" "$ip" "$count"
    done
    
    echo ""
}

###############################################################################
# 5. 异常请求分析
###############################################################################
anomaly_analysis() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  5. 异常请求分析${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # 4xx 错误
    ERROR_4XX=$(awk '$9 ~ /^4/' "$LOG_FILE" | wc -l)
    echo -e "  4xx 客户端错误: ${YELLOW}${ERROR_4XX}${NC} 次"
    
    # 5xx 错误
    ERROR_5XX=$(awk '$9 ~ /^5/' "$LOG_FILE" | wc -l)
    echo -e "  5xx 服务器错误: ${RED}${ERROR_5XX}${NC} 次"
    
    # 可疑IP（访问次数超过100次）
    echo -e "\n  ${YELLOW}可疑IP (访问>100次):${NC}"
    awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | awk '$1 > 100 {printf "    %-20s %s 次\n", $2, $1}'
    
    # 404 错误URL
    echo -e "\n  ${YELLOW}404 错误 URL:${NC}"
    awk '$9 == "404" {print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -5 | while read count url; do
        printf "    %-50s %s 次\n" "$url" "$count"
    done
    
    echo ""
}

###############################################################################
# 6. 访问时间分布
###############################################################################
time_distribution() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  6. 小时访问分布${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    awk -F'[/:]' '{print $4}' "$LOG_FILE" | sort | uniq -c | sort -k2n | while read count hour; do
        bar=$(printf '%0.s█' $(seq 1 $((count / 10 + 1))))
        printf "  %s:00  %-50s %s\n" "$hour" "$bar" "$count"
    done
    
    echo ""
}

###############################################################################
# 7. 生成分析报告
###############################################################################
generate_report() {
    mkdir -p "$REPORT_DIR"
    REPORT_FILE="$REPORT_DIR/log_analysis_${TIMESTAMP}.txt"
    
    {
        echo "Nginx 日志分析报告"
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "日志文件: $LOG_FILE"
        echo "========================================"
        echo ""
        echo "1. 基础统计"
        echo "  总请求数 (PV): $TOTAL_REQUESTS"
        echo "  独立IP数 (UV): $UNIQUE_IPS"
        echo ""
        echo "2. HTTP 状态码分布"
        awk '{print $9}' "$LOG_FILE" | sort | uniq -c | sort -rn | while read count code; do
            printf "  %-6s %s 次 (%.1f%%)\n" "$code" "$count" "$(echo "scale=1; $count*100/$TOTAL_REQUESTS" | bc)"
        done
        echo ""
        echo "3. 热门 URL Top 10"
        awk '{print $7}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10 | while read count url; do
            printf "  %-50s %s 次\n" "$url" "$count"
        done
        echo ""
        echo "4. 访问IP Top 10"
        awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -rn | head -10 | while read count ip; do
            printf "  %-20s %s 次\n" "$ip" "$count"
        done
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}分析报告已保存: $REPORT_FILE${NC}"
}

###############################################################################
# 主函数
###############################################################################
main() {
    echo "=============================================="
    echo "  Nginx 日志分析工具 v1.0"
    echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""
    
    check_log_file
    basic_stats
    status_code_stats
    top_urls
    top_ips
    anomaly_analysis
    time_distribution
    generate_report
    
    echo "=============================================="
    echo -e "${GREEN}分析完成！${NC}"
    echo "=============================================="
}

main "$@"
