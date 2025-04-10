#!/usr/bin/env bash

# Copyright (c) 2024-2025
# Author: fevirtus
# License: MIT
# Description: Create LXC & Install Kavita (non-Docker)
# Source: https://www.kavitareader.com/

set -Eeuo pipefail

# ========== Config ==========
TEMPLATE="debian-12-standard"
TEMPLATE_STORAGE="local"
STORAGE="local-lvm"
BRIDGE="vmbr0"
DISK_SIZE="8G"
RAM=2048
CPUS=2
HOSTNAME="kavita"
PASSWORD="kavitapass"
# ============================

# ========== UI Helpers ==========
msg_info() { echo -e "🟡 \033[1;34m$1...\033[0m"; }
msg_ok()   { echo -e "🟢 \033[1;32m$1\033[0m"; }
msg_error(){ echo -e "🔴 \033[1;31m$1\033[0m"; }
catch_errors() {
  msg_error "Script failed at line $1: $BASH_COMMAND"
  exit 1
}
trap 'catch_errors $LINENO' ERR
# ================================

# ========== Step 1: Create LXC ==========
msg_info "Tìm VMID khả dụng"
VMID=$(pvesh get /cluster/nextid)
msg_ok "Sử dụng VMID $VMID"

msg_info "Kiểm tra template Ubuntu"
if [ ! -f "/var/lib/vz/template/cache/$TEMPLATE" ]; then
  pveam update
  pveam download $TEMPLATE_STORAGE ${TEMPLATE%%_*}
fi
msg_ok "Đã sẵn sàng template"

msg_info "Tạo container $HOSTNAME ($VMID)"
pct create $VMID $TEMPLATE_STORAGE:vztmpl/$TEMPLATE \
  -hostname $HOSTNAME \
  -rootfs $STORAGE:$DISK_SIZE \
  -memory $RAM \
  -cores $CPUS \
  -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  -unprivileged 0 \
  -password $PASSWORD \
  -features nesting=1,fuse=1,keyctl=1,mount=1 \
  -onboot 1
pct start $VMID
msg_ok "Container đã được tạo và khởi động"

# ========== Step 2: Install Kavita ==========
msg_info "Cài đặt Kavita trong LXC $VMID"

pct exec $VMID -- bash -c "apt update && apt install -y curl tar"

# Tải bản mới nhất
RELEASE=$(curl -fsSL https://api.github.com/repos/Kareadita/Kavita/releases/latest | grep "tag_name" | cut -d '"' -f4)
pct exec $VMID -- mkdir -p /opt
pct exec $VMID -- bash -c "curl -fsSL https://github.com/Kareadita/Kavita/releases/download/$RELEASE/kavita-linux-x64.tar.gz | tar -xz -C /opt --no-same-owner"

msg_ok "Đã cài đặt Kavita v$RELEASE"

# ========== Step 3: Create Service ==========
msg_info "Tạo systemd service cho Kavita"
SERVICE_PATH="/etc/systemd/system/kavita.service"

pct exec $VMID -- bash -c "cat <<EOF > $SERVICE_PATH
[Unit]
Description=Kavita Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/Kavita
ExecStart=/opt/Kavita/Kavita
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF"

pct exec $VMID -- bash -c "chmod +x /opt/Kavita/* && chown root /opt/Kavita/*"
pct exec $VMID -- systemctl enable --now kavita.service
msg_ok "Service Kavita đã khởi động"

# ========== Step 4: Cài đặt rclone ==========
msg_info "Cài đặt rclone và mount Google Drive"
pct exec $VMID -- apt install -y rclone fuse3

msg_info "Tạo thư mục mount /mnt/books"
pct exec $VMID -- mkdir -p /mnt/books

msg_info "Cấu hình rclone (yêu cầu thao tác thủ công)"
echo -e "\n🔗 Truy cập LXC bằng: \033[1;33mpct enter $VMID\033[0m"
echo "Sau đó chạy: \033[1;32mrclone config\033[0m để thêm remote tên \033[1;36mdrive\033[0m"
echo "Khi hoàn tất, gõ exit để quay lại."

read -p "👉 Nhấn Enter khi bạn đã cấu hình xong rclone..."

msg_info "Tạo systemd mount cho Google Drive"
MOUNT_SERVICE_PATH="/etc/systemd/system/rclone-drive.mount"
pct exec $VMID -- bash -c "cat <<EOF > $MOUNT_SERVICE_PATH
[Unit]
Description=Rclone Mount for Google Drive
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount drive: /mnt/books \\
  --allow-other \\
  --dir-cache-time 1000h \\
  --poll-interval 15s \\
  --umask 002 \\
  --vfs-cache-mode full \\
  --vfs-cache-max-age 12h \\
  --vfs-read-chunk-size 32M \\
  --vfs-read-chunk-size-limit 2G
ExecStop=/bin/fusermount -u /mnt/books
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF"

pct exec $VMID -- systemctl enable --now rclone-drive.mount
msg_ok "Đã mount Google Drive tại /mnt/books"

# ========== Step 5: Cấu hình thư viện Kavita ==========
msg_info "Tạo thư mục thư viện mặc định cho Kavita"
pct exec $VMID -- mkdir -p /opt/Kavita/Data/Library

msg_info "Gắn /mnt/books vào thư viện Kavita"
pct exec $VMID -- ln -s /mnt/books /opt/Kavita/Data/Library/GoogleDrive
msg_ok "Kavita sẽ đọc sách từ Google Drive tại tab 'GoogleDrive'"

# ========== Step 6: Hoàn tất ==========
LXC_IP=$(pct exec $VMID -- hostname -I | awk '{print $1}')
msg_ok "✅ Kavita đã sẵn sàng tại: http://$LXC_IP:5000"
echo "🔐 SSH: pct enter $VMID  |  Tên máy: $HOSTNAME"