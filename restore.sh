#!/bin/bash
set -e

BACKUP_PATH="/root/1panel-migration-backup.tar.gz"
TARGET_DIR="/opt"

echo "=========================================="
echo "          1Panel 迁移 - 新服务器恢复工具          "
echo "=========================================="

# 1. 检查备份文件
if [ ! -f "$BACKUP_PATH" ]; then
    echo "[X] 错误: 未在 ${BACKUP_PATH} 找到备份文件！"
    echo "[i] 请先将旧服务器的备份文件 scp 到新服务器的 /root/ 目录下再运行本脚本。"
    exit 1
fi

# 2. 系统更新与依赖安装
echo "[-] 正在更新系统软件源及基础工具..."
apt update && apt upgrade -y
apt install apt-transport-https build-essential git curl wget unzip tmux btop bind9-dnsutils tree vim -y

# 3. 恢复数据
echo "[-] 正在恢复 1Panel 数据到 ${TARGET_DIR}..."
mkdir -p $TARGET_DIR
tar -xzvf $BACKUP_PATH -C $TARGET_DIR

# 4. 在线安装/恢复 1Panel（使用官方国内源加速）
echo "[-] 正在运行 1Panel 官方安装脚本..."
bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"

# 5. 重启并验证
echo "[-] 正在重启 1Panel 服务..."
1pctl stop all
1pctl start all

echo "=========================================="
echo "[-] 正在验证 1Panel 服务状态..."
1pctl status

echo "=========================================="
echo "[√] 1Panel 迁移恢复完成！"
echo "[i] 以下是您的登录信息："
1pctl user-info
echo "=========================================="
