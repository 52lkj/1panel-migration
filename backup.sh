#!/bin/bash
set -e

# ==================== 配置区 ====================
BACKUP_DIR="/opt"
BACKUP_NAME="1panel-migration-backup.tar.gz"
TARGET_DIR="/root"
LOG_FILE="/tmp/1panel-backup-$(date +%Y%m%d-%H%M%S).log"
MIN_DISK_SPACE_MB=1024  # 最小可用空间（MB）

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        log_error "请使用: sudo $0"
        exit 1
    fi
}

# ==================== 磁盘空间检查 ====================
check_disk_space() {
    log_info "检查磁盘空间..."
    
    local available_space=$(df -m "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    
    if [[ $available_space -lt $MIN_DISK_SPACE_MB ]]; then
        log_error "磁盘空间不足！需要至少 ${MIN_DISK_SPACE_MB}MB，当前可用: ${available_space}MB"
        exit 1
    fi
    
    log_info "磁盘空间检查通过 (可用: ${available_space}MB)"
}

# ==================== 检查 1Panel 是否安装 ====================
check_1panel_installed() {
    if [[ ! -d "/opt/1panel" ]]; then
        log_error "未检测到 1Panel 安装目录 (/opt/1panel)"
        log_error "请确认 1Panel 已正确安装"
        exit 1
    fi
    
    if [[ ! -f "/opt/1panel/1panel" ]]; then
        log_error "未找到 1Panel 可执行文件"
        exit 1
    fi
}

# ==================== 停止 1Panel 服务 ====================
stop_1panel_services() {
    log_info "正在停止 1Panel 相关服务..."
    
    # 检查 1pctl 是否存在
    if command -v 1pctl &> /dev/null; then
        log_info "使用 1pctl 停止服务..."
        
        # 获取运行中的容器
        local running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "^1panel-" || true)
        
        if [[ -n "$running_containers" ]]; then
            log_info "发现运行中的 1Panel 容器，正在停止..."
            1pctl stop all || {
                log_warn "1pctl stop 失败，尝试直接停止 Docker 容器..."
                docker stop $(docker ps -q --filter "name=1panel-") || true
            }
        else
            log_info "没有运行中的 1Panel 容器"
        fi
        
        # 停止 1panel 服务本身
        systemctl stop 1panel 2>/dev/null || true
        
    else
        log_warn "未找到 1pctl 命令，尝试使用 Docker 和 systemctl..."
        docker stop $(docker ps -q --filter "name=1panel-") 2>/dev/null || true
        systemctl stop 1panel 2>/dev/null || true
    fi
    
    sleep 3
    log_info "服务停止完成"
}

# ==================== 创建备份 ====================
create_backup() {
    log_info "开始打包 1Panel 数据..."
    log_info "源目录: /opt/1panel"
    log_info "目标文件: ${TARGET_DIR}/${BACKUP_NAME}"
    
    # 检查源目录是否存在
    if [[ ! -d "/opt/1panel" ]]; then
        log_error "/opt/1panel 目录不存在"
        exit 1
    fi
    
    # 获取目录大小
    local dir_size=$(du -sm /opt/1panel | cut -f1)
    log_info "1Panel 目录大小: ${dir_size}MB"
    
    # 切换到备份目录
    cd "$BACKUP_DIR"
    
    # 创建备份（排除缓存和临时文件）
    log_info "正在创建压缩备份（这可能需要几分钟）..."
    
    tar --exclude='1panel/cache/*' \
        --exclude='1panel/tmp/*' \
        --exclude='1panel/log/*.log' \
        -czvf "${TARGET_DIR}/${BACKUP_NAME}" \
        1panel 2>&1 | tee -a "$LOG_FILE"
    
    # 验证备份文件
    if [[ ! -f "${TARGET_DIR}/${BACKUP_NAME}" ]]; then
        log_error "备份文件创建失败！"
        exit 1
    fi
    
    local backup_size=$(du -h "${TARGET_DIR}/${BACKUP_NAME}" | cut -f1)
    local backup_checksum=$(md5sum "${TARGET_DIR}/${BACKUP_NAME}" | cut -d' ' -f1)
    
    log_info "备份文件创建成功！"
    log_info "文件大小: ${backup_size}"
    log_info "MD5 校验和: ${backup_checksum}"
    log_info "文件路径: ${TARGET_DIR}/${BACKUP_NAME}"
    
    # 保存校验和到单独文件
    echo "${backup_checksum}  ${BACKUP_NAME}" > "${TARGET_DIR}/1panel-backup.md5"
    log_info "MD5 校验文件已保存: ${TARGET_DIR}/1panel-backup.md5"
}

# ==================== 显示传输说明 ====================
show_transfer_info() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✓ 备份完成！${NC}"
    echo "=========================================="
    echo ""
    echo -e "${BLUE}下一步操作：${NC}"
    echo "1. 将备份文件传输到新服务器："
    echo -e "   ${YELLOW}scp ${TARGET_DIR}/${BACKUP_NAME} root@新服务器IP:/root/${NC}"
    echo ""
    echo "2. 将 MD5 校验文件也传输过去（推荐）："
    echo -e "   ${YELLOW}scp ${TARGET_DIR}/1panel-backup.md5 root@新服务器IP:/root/${NC}"
    echo ""
    echo "3. 在新服务器上运行恢复脚本"
    echo ""
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
    echo "=========================================="
}

# ==================== 主流程 ====================
main() {
    echo "=========================================="
    echo -e "${BLUE}     1Panel 迁移 - 旧服务器打包工具${NC}"
    echo "=========================================="
    echo ""
    
    check_root
    check_disk_space
    check_1panel_installed
    
    # 确认提示
    echo ""
    log_warn "即将停止 1Panel 服务并创建备份"
    read -p "是否继续？[y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        exit 0
    fi
    
    stop_1panel_services
    create_backup
    show_transfer_info
    
    # 提示是否重启服务
    echo ""
    read -p "是否现在重启 1Panel 服务？[y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "正在重启 1Panel 服务..."
        systemctl start 1panel 2>/dev/null || true
        sleep 5
        if command -v 1pctl &> /dev/null; then
            1pctl status
        fi
        log_info "服务已重启"
    else
        log_warn "服务保持停止状态，请记得手动启动: systemctl start 1panel"
    fi
}

# 执行主流程
main "$@"
