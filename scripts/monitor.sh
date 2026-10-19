#!/bin/bash
###############################################################################
# 系统资源监控脚本
# 功能: 实时监控CPU、内存、磁盘、网络、Docker容器资源使用情况
# 用法: ./monitor.sh [interval_seconds]
# 示例: ./monitor.sh 5  (每5秒刷新一次)
###############################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 配置
INTERVAL="${1:-5}"  # 默认5秒刷新
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs/monitor"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=80
ALERT_THRESHOLD_DISK=80

mkdir -p "$LOG_DIR"

###############################################################################
# 清屏并显示标题
###############################################################################
show_header() {
    clear
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║           LNMP 系统资源监控面板 v1.0                              ║${NC}"
    echo -e "${WHITE}║           时间: $(date '+%Y-%m-%d %H:%M:%S')                          ║${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

###############################################################################
# 1. CPU 监控
###############################################################################
show_cpu() {
    echo -e "${CYAN}┌─ CPU 使用情况 ─────────────────────────────────────────┐${NC}"
    
    # CPU 核心数
    CPU_CORES=$(nproc 2>/dev/null || grep -c processor /proc/cpuinfo)
    echo -e "│  CPU核心数: ${WHITE}${CPU_CORES}${NC}"
    
    # CPU 使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    CPU_INT=${CPU_USAGE%.*}
    
    if [ "$CPU_INT" -ge "$ALERT_THRESHOLD_CPU" ]; then
        COLOR="$RED"
        ALERT="⚠️  CPU使用率过高！"
    elif [ "$CPU_INT" -ge 60 ]; then
        COLOR="$YELLOW"
        ALERT=""
    else
        COLOR="$GREEN"
        ALERT=""
    fi
    
    # 进度条
    BAR_LENGTH=40
    FILLED=$((CPU_INT * BAR_LENGTH / 100))
    BAR=$(printf '%0.s█' $(seq 1 $FILLED 2>/dev/null))
    EMPTY=$(printf '%0.s░' $(seq 1 $((BAR_LENGTH - FILLED)) 2>/dev/null))
    
    echo -e "│  CPU使用率: ${COLOR}${BAR}${EMPTY} ${CPU_USAGE}%${NC} $ALERT"
    
    # 负载
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "│  系统负载: ${WHITE}${LOAD_AVG}${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

###############################################################################
# 2. 内存监控
###############################################################################
show_memory() {
    echo -e "${CYAN}┌─ 内存使用情况 ─────────────────────────────────────────┐${NC}"
    
    # 获取内存信息
    MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
    MEM_USED=$(free -h | grep Mem | awk '{print $3}')
    MEM_FREE=$(free -h | grep Mem | awk '{print $4}')
    MEM_AVAILABLE=$(free -h | grep Mem | awk '{print $7}')
    MEM_PERCENT=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    MEM_INT=${MEM_PERCENT%.*}
    
    if [ "$MEM_INT" -ge "$ALERT_THRESHOLD_MEM" ]; then
        COLOR="$RED"
        ALERT="⚠️  内存使用率过高！"
    elif [ "$MEM_INT" -ge 60 ]; then
        COLOR="$YELLOW"
        ALERT=""
    else
        COLOR="$GREEN"
        ALERT=""
    fi
    
    BAR_LENGTH=40
    FILLED=$((MEM_INT * BAR_LENGTH / 100))
    BAR=$(printf '%0.s█' $(seq 1 $FILLED 2>/dev/null))
    EMPTY=$(printf '%0.s░' $(seq 1 $((BAR_LENGTH - FILLED)) 2>/dev/null))
    
    echo -e "│  内存使用: ${COLOR}${BAR}${EMPTY} ${MEM_PERCENT}%${NC} $ALERT"
    echo -e "│  总内存: ${WHITE}${MEM_TOTAL}${NC}  已用: ${WHITE}${MEM_USED}${NC}  可用: ${WHITE}${MEM_AVAILABLE}${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

###############################################################################
# 3. 磁盘监控
###############################################################################
show_disk() {
    echo -e "${CYAN}┌─ 磁盘使用情况 ─────────────────────────────────────────┐${NC}"
    
    df -h / | tail -1 | while read filesystem size used avail percent mount; do
        DISK_INT=${percent%.*}
        
        if [ "$DISK_INT" -ge "$ALERT_THRESHOLD_DISK" ]; then
            COLOR="$RED"
            ALERT="️  磁盘使用率过高！"
        elif [ "$DISK_INT" -ge 60 ]; then
            COLOR="$YELLOW"
            ALERT=""
        else
            COLOR="$GREEN"
            ALERT=""
        fi
        
        BAR_LENGTH=40
        FILLED=$((DISK_INT * BAR_LENGTH / 100))
        BAR=$(printf '%0.s█' $(seq 1 $FILLED 2>/dev/null))
        EMPTY=$(printf '%0.s░' $(seq 1 $((BAR_LENGTH - FILLED)) 2>/dev/null))
        
        echo -e "│  磁盘使用: ${COLOR}${BAR}${EMPTY} ${percent}${NC} $ALERT"
        echo -e "│  挂载点: ${WHITE}${mount}${NC}  总大小: ${WHITE}${size}${NC}  已用: ${WHITE}${used}${NC}  可用: ${WHITE}${avail}${NC}"
    done
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

###############################################################################
# 4. Docker 容器监控
###############################################################################
show_docker() {
    echo -e "${CYAN}┌─ Docker 容器状态 ──────────────────────────────────────┐${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "│  ${YELLOW}Docker 未安装${NC}"
    else
        # 容器列表
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | while IFS= read -r line; do
            echo -e "│  $line"
        done
        
        # Docker 资源使用
        echo -e "│"
        echo -e "│  ${WHITE}容器资源使用:${NC}"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | while IFS= read -r line; do
            echo -e "│  $line"
        done
    fi
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

###############################################################################
# 5. 网络监控
###############################################################################
show_network() {
    echo -e "${CYAN}┌─ 网络状态 ─────────────────────────────────────────────┐${NC}"
    
    # 网络连接统计
    echo -e "│  ${WHITE}TCP连接状态:${NC}"
    netstat -an 2>/dev/null | grep "^tcp" | awk '{print $6}' | sort | uniq -c | sort -rn | while read count state; do
        printf "│    %-20s %s\n" "$state" "$count"
    done
    
    # 监听端口
    echo -e "│"
    echo -e "│  ${WHITE}监听端口:${NC}"
    netstat -tlnp 2>/dev/null | grep LISTEN | awk '{print $4, $7}' | while read port process; do
        printf "│    %-20s %s\n" "$port" "$process"
    done
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

###############################################################################
# 6. 进程 Top 5
###############################################################################
show_top_processes() {
    echo -e "${CYAN}┌─ CPU/内存占用 Top 5 进程 ──────────────────────────────┐${NC}"
    
    echo -e "│  ${WHITE}CPU Top 5:${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "│    %-8s %-6s %-6s %s\n", $1, $3"%", $4"%", $11}' 
    
    echo -e "│"
    echo -e "│  ${WHITE}内存 Top 5:${NC}"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "│    %-8s %-6s %-6s %s\n", $1, $3"%", $4"%", $11}'
    
    echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
}

###############################################################################
# 记录监控数据
###############################################################################
log_metrics() {
    local log_file="$LOG_DIR/metrics_$(date +%Y%m%d).csv"
    
    if [ ! -f "$log_file" ]; then
        echo "timestamp,cpu_percent,mem_percent,disk_percent" > "$log_file"
    fi
    
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    MEM_PERCENT=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    DISK_PERCENT=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$CPU_USAGE,$MEM_PERCENT,$DISK_PERCENT" >> "$log_file"
}

###############################################################################
# 主循环
###############################################################################
main() {
    echo "LNMP 系统资源监控"
    echo "刷新间隔: ${INTERVAL}秒"
    echo "按 Ctrl+C 退出"
    echo ""
    sleep 2
    
    while true; do
        show_header
        show_cpu
        show_memory
        show_disk
        show_docker
        show_network
        show_top_processes
        log_metrics
        
        echo -e "${WHITE}下次刷新: ${INTERVAL}秒后... (Ctrl+C 退出)${NC}"
        sleep "$INTERVAL"
    done
}

main "$@"
