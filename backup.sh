#!/bin/bash
set -e

BACKUP_DIR="/opt"
BACKUP_NAME="1panel-migration-backup.tar.gz"
TARGET_DIR="/root"

echo "=========================================="
echo "          1Panel 迁移 - 旧服务器打包工具          "
echo "=========================================="

# 1. 停止 1Panel 服务
echo "[-] 正在停止 1Panel 服务..."
if command -v 1pctl &> /dev/null; then
    1pctl stop all
else
    echo "[!] 未找到 1pctl 命令，尝试直接打包..."
fi

# 2. 打包数据
echo "[-] 正在打包 /opt/1panel 目录..."
cd $BACKUP_DIR
tar -czvf ${TARGET_DIR}/${BACKUP_NAME} 1panel

if [ $? -eq 0 ]; then
    echo "=========================================="
    echo "[√] 打包成功！"
    echo "[i] 备份文件路径: ${TARGET_DIR}/${BACKUP_NAME}"
    echo "[i] 请在旧服务器执行以下命令将文件传输至新服务器："
    echo "    scp ${TARGET_DIR}/${BACKUP_NAME} root@新服务器IP:/root/"
    echo "=========================================="
else
    echo "[X] 打包失败，请检查磁盘空间！"
    exit 1
fi
