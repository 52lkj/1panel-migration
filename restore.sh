#!/bin/bash
set -e

# ==================== 配置区 ====================
BACKUP_PATH="/root/1panel-migration-backup.tar.gz"
MD5_PATH="/root/1panel-backup.md5"
TARGET_DIR="/opt"
LOG_FILE="/tmp/1panel-restore-$(date +%Y%m%d-%H%M%S).log"

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==================== 日志函数 ====================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# ==================== 权限检查 ====================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        exit 1
    fi
}

# ==================== 检查备份文件 ====================
check_backup_file() {
    log_info "检查备份文件..."
    
    if [[ ! -f "$BACKUP_PATH" ]]; then
        log_error "备份文件不存在: $BACKUP_PATH"
        log_error "请先从旧服务器传输备份文件到新服务器"
        exit 1
    fi
    
    # 验证 MD5 校验和（如果存在）
    if [[ -f "$MD5_PATH" ]]; then
        log_info "验证 MD5 校验和..."
        local expected_md5=$(cat "$MD5_PATH" | cut -d' ' -f1)
        local actual_md5=$(md5sum "$BACKUP_PATH" | cut -d' ' -f1)
        
        if [[ "$expected_md5" == "$actual_md5" ]]; then
            log_info "MD5 校验通过 ✓"
        else
            log_error "MD5 校验失败！"
            log_error "期望: $expected_md5"
            log_error "实际: $actual_md5"
            log_error "文件可能已损坏，请重新传输"
            exit 1
        fi
    else
        log_warn "未找到 MD5 校验文件，跳过完整性验证"
    fi
    
    local backup_size=$(du -h "$BACKUP_PATH" | cut -f1)
    log_info "备份文件大小: $backup_size"
}

# ==================== 系统检测 ====================
detect_os() {
    log_info "检测操作系统..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
        log_info "操作系统: $OS_NAME $OS_VERSION"
    else
        log_error "无法检测操作系统版本"
        exit 1
    fi
    
    # 确定包管理器
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        log_info "包管理器: apt (Debian/Ubuntu)"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        log_info "包管理器: yum (CentOS/RHEL)"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        log_info "包管理器: dnf (Fedora/RHEL8+)"
    else
        log_error "未找到支持的包管理器 (apt/yum/dnf)"
        exit 1
    fi
}

# ==================== 系统更新和依赖安装 ====================
install_dependencies() {
    log_info "更新系统并安装基础依赖..."
    
    case $PKG_MANAGER in
        apt)
            apt-get update -y
            apt-get install -y curl wget tar gzip
            ;;
        yum|dnf)
            $PKG_MANAGER makecache
            $PKG_MANAGER install -y curl wget tar gzip
            ;;
    esac
    
    log_info "依赖安装完成"
}

# ==================== 检查 Docker ====================
check_docker() {
    log_info "检查 Docker 环境..."
    
    if ! command -v docker &> /dev/null; then
        log_warn "Docker 未安装，1Panel 安装脚本会自动安装"
        return 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        log_warn "Docker 服务未运行，尝试启动..."
        systemctl start docker || {
            log_error "无法启动 Docker 服务"
            exit 1
        }
    fi
    
    log_info "Docker 状态正常"
    return 0
}

# ==================== 安装 1Panel ====================
install_1panel() {
    log_info "开始安装 1Panel..."
    
    # 检查是否已安装
    if [[ -d "/opt/1panel" ]] && [[ -f "/opt/1panel/1panel" ]]; then
        log_warn "检测到 1Panel 已安装"
        read -p "是否覆盖现有安装？[y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            exit 0
        fi
        
        log_info "停止现有 1Panel 服务..."
        systemctl stop 1panel 2>/dev/null || true
        if command -v 1pctl &> /dev/null; then
            1pctl stop all 2>/dev/null || true
        fi
        sleep 3
    fi
    
    # 下载并运行官方安装脚本
    log_info "下载 1Panel 官方安装脚本..."
    
    local install_script="/tmp/1panel-install.sh"
    curl -fsSL -o "$install_script" https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh
    
    if [[ ! -s "$install_script" ]]; then
        log_error "下载官方安装脚本失败"
        exit 1
    fi
    
    log_info "运行官方安装脚本..."
    bash "$install_script"
    
    # 等待安装完成
    sleep 5
    
    # 验证安装
    if [[ ! -f "/opt/1panel/1panel" ]]; then
        log_error "1Panel 安装失败"
        exit 1
    fi
    
    log_info "1Panel 安装成功"
}

# ==================== 恢复数据 ====================
restore_data() {
    log_info "开始恢复 1Panel 数据..."
    
    # 停止服务
    log_info "停止 1Panel 服务..."
    systemctl stop 1panel 2>/dev/null || true
    if command -v 1pctl &> /dev/null; then
        1pctl stop all 2>/dev/null || true
    fi
    sleep 3
    
    # 备份现有数据（以防万一）
    if [[ -d "/opt/1panel" ]]; then
        local backup_old="/opt/1panel.backup.$(date +%Y%m%d-%H%M%S)"
        log_info "备份现有数据到: $backup_old"
        mv /opt/1panel "$backup_old"
    fi
    
    # 解压备份
    log_info "解压备份文件到 /opt..."
    cd /opt
    tar -xzvf "$BACKUP_PATH"
    
    if [[ ! -d "/opt/1panel" ]]; then
        log_error "解压失败，/opt/1panel 目录不存在"
        exit 1
    fi
    
    # 修复权限
    log_info "修复文件权限..."
    chown -R root:root /opt/1panel
    chmod -R 755 /opt/1panel
    
    log_info "数据恢复完成"
}

# ==================== 启动服务 ====================
start_services() {
    log_info "启动 1Panel 服务..."
    
    # 启动 Docker 容器
    if command -v 1pctl &> /dev/null; then
        log_info "使用 1pctl 启动所有服务..."
        1pctl start all || {
            log_warn "1pctl start 失败，尝试手动启动..."
            docker start $(docker ps -aq --filter "name=1panel-") 2>/dev/null || true
        }
    else
        docker start $(docker ps -aq --filter "name=1panel-") 2>/dev/null || true
    fi
    
    # 启动 1panel 服务
    systemctl start 1panel
    systemctl enable 1panel
    
    sleep 10
    
    # 验证服务状态
    log_info "验证服务状态..."
    if systemctl is-active --quiet 1panel; then
        log_info "1Panel 服务运行正常 ✓"
    else
        log_error "1Panel 服务启动失败"
        exit 1
    fi
    
    # 检查 Docker 容器
    local running_containers=$(docker ps --filter "name=1panel-" --format '{{.Names}}' | wc -l)
    log_info "运行中的 1Panel 容器数: $running_containers"
}

# ==================== 显示登录信息 ====================
show_login_info() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✓ 迁移完成！${NC}"
    echo "=========================================="
    echo ""
    
    # 等待服务完全启动
    sleep 5
    
    if command -v 1pctl &> /dev/null; then
        log_info "获取登录信息..."
        echo ""
        1pctl user-info 2>/dev/null || {
            log_warn "无法获取用户信息，请查看面板日志"
        }
    fi
    
    echo ""
    echo -e "${BLUE}面板访问地址:${NC}"
    echo "  http://$(curl -s ifconfig.me):端口号"
    echo ""
    echo -e "${YELLOW}如果无法访问，请检查：${NC}"
    echo "  1. 服务器防火墙/安全组是否放行面板端口"
    echo "  2. 使用 '1pctl user-info' 查看端口号"
    echo "  3. 查看日志: journalctl -u 1panel -f"
    echo ""
    echo -e "${BLUE}日志文件:${NC}"
    echo "  $LOG_FILE"
    echo "=========================================="
}

# ==================== 主流程 ====================
main() {
    echo "=========================================="
    echo -e "${BLUE}     1Panel 迁移 - 新服务器恢复工具${NC}"
    echo "=========================================="
    echo ""
    
    check_root
    check_backup_file
    detect_os
    
    # 确认提示
    echo ""
    log_warn "警告：此操作将安装/覆盖 1Panel 并恢复数据"
    log_warn "请确保已备份新服务器上的重要数据"
    echo ""
    read -p "是否继续？[y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    install_dependencies
    install_1panel
    restore_data
    start_services
    show_login_info
}

# 执行主流程
main "$@"
