#!/bin/bash
###############################################################################
# LNMP 一键部署脚本
# 功能: 自动安装Docker/Docker Compose，部署LNMP环境
# 作者: 运维工程师项目
# 日期: 2026-10-16
###############################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# 获取项目根目录
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

###############################################################################
# 第一步: 检查系统环境
###############################################################################
check_system() {
    log_info "检查系统环境..."
    
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "操作系统: $OS $VER"
    else
        log_warn "无法识别操作系统"
    fi
    
    # 检查是否以root运行
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
    
    log_success "系统环境检查完成"
}

###############################################################################
# 第二步: 安装 Docker
###############################################################################
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装: $(docker --version)"
        return 0
    fi
    
    log_info "开始安装 Docker..."
    
    if [ "$OS" = "centos" ] || [ "$OS" = "rhel" ]; then
        # CentOS/RHEL 安装 Docker
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
        systemctl enable docker
    elif [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        # Ubuntu/Debian 安装 Docker
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
        systemctl enable docker
    else
        log_error "不支持的操作系统: $OS"
        exit 1
    fi
    
    log_success "Docker 安装完成: $(docker --version)"
}

###############################################################################
# 第三步: 安装 Docker Compose
###############################################################################
install_docker_compose() {
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log_info "Docker Compose 已安装"
        return 0
    fi
    
    log_info "开始安装 Docker Compose..."
    
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker Compose 安装完成: $(docker-compose --version)"
}

###############################################################################
# 第四步: 创建必要目录
###############################################################################
create_dirs() {
    log_info "创建项目目录..."
    
    mkdir -p "$PROJECT_DIR"/{logs/nginx,logs/mysql,app,nginx,mysql,scripts}
    
    log_success "目录创建完成"
}

###############################################################################
# 第五步: 配置环境变量
###############################################################################
setup_env() {
    log_info "配置环境变量..."
    
    ENV_FILE="$PROJECT_DIR/.env"
    
    if [ ! -f "$ENV_FILE" ]; then
        cat > "$ENV_FILE" << EOF
# MySQL 配置
MYSQL_ROOT_PASSWORD=root123456
MYSQL_DATABASE=lnmp_db
MYSQL_USER=lnmp_user
MYSQL_PASSWORD=lnmp123456

# 项目配置
PROJECT_NAME=lnmp-ops
EOF
        log_info "已创建 .env 文件"
    else
        log_info ".env 文件已存在，跳过创建"
    fi
    
    log_success "环境变量配置完成"
}

###############################################################################
# 第六步: 启动服务
###############################################################################
start_services() {
    log_info "启动 LNMP 服务..."
    
    cd "$PROJECT_DIR"
    
    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    docker-compose pull
    
    # 启动服务
    log_info "启动容器..."
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    log_info "检查服务状态..."
    docker-compose ps
    
    log_success "LNMP 服务启动完成！"
    log_info "访问地址: http://localhost:8080"
    log_info "MySQL 端口: 3306"
}

###############################################################################
# 第七步: 验证部署
###############################################################################
verify_deployment() {
    log_info "验证部署..."
    
    # 检查容器是否运行
    RUNNING=$(docker-compose ps --services --filter "status=running" | wc -l)
    TOTAL=$(docker-compose ps --services | wc -l)
    
    if [ "$RUNNING" -eq "$TOTAL" ]; then
        log_success "所有 $TOTAL 个服务运行正常"
    else
        log_warn "部分服务未正常运行，请检查日志: docker-compose logs"
    fi
    
    # 测试 Nginx
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200\|301\|302"; then
        log_success "Nginx 响应正常"
    else
        log_warn "Nginx 响应异常，请检查配置"
    fi
    
    # 测试 MySQL
    if docker exec lnmp-mysql mysqladmin ping -h localhost -uroot -proot123456 2>/dev/null | grep -q "alive"; then
        log_success "MySQL 运行正常"
    else
        log_warn "MySQL 响应异常，请检查日志"
    fi
}

###############################################################################
# 主函数
###############################################################################
main() {
    echo "=============================================="
    echo "  LNMP 自动化部署脚本 v1.0"
    echo "  作者: 运维工程师面试项目"
    echo "=============================================="
    echo ""
    
    check_system
    install_docker
    install_docker_compose
    create_dirs
    setup_env
    start_services
    verify_deployment
    
    echo ""
    echo "=============================================="
    log_success "部署完成！"
    echo "  应用地址: http://localhost:8080"
    echo "  MySQL地址: localhost:3306"
    echo "  数据库名: lnmp_db"
    echo "  用户名: lnmp_user"
    echo "  密码: lnmp123456"
    echo "=============================================="
}

# 执行主函数
main "$@"
