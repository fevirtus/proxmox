#!/bin/bash

set -e

# ====== CẤU HÌNH MẶC ĐỊNH ====== #
HOSTNAME="kavita"
PASSWORD="kavitapass"
STORAGE="local-lvm"
DISK_SIZE="8G"
RAM="2048"
CPU_CORES=2
NET_BRIDGE="vmbr0"
TEMPLATE_NAME="ubuntu-22.04-standard_20240110.tar.zst"
TEMPLATE_PATH="local:vztmpl/$TEMPLATE_NAME"
# =============================== #

echo "📦 Tạo LXC Proxmox + Cài đặt Kavita bên trong..."

# Tự động tìm VMID chưa dùng
NEXTID=$(pvesh get /cluster/nextid)
echo "🆔 Dùng VMID $NEXTID"

# Kiểm tra template đã có chưa
if ! pct list | grep -q "$TEMPLATE_NAME" && ! ls /var/lib/vz/template/cache/$TEMPLATE_NAME &>/dev/null; then
  echo "⬇️ Chưa có template $TEMPLATE_NAME. Đang tải..."
  pveam update
  pveam download local $TEMPLATE_NAME
fi

# Tạo container
pct create $NEXTID $TEMPLATE_PATH \
  -hostname $HOSTNAME \
  -storage $STORAGE \
  -rootfs $DISK_SIZE \
  -memory $RAM \
  -cores $CPU_CORES \
  -net0 name=eth0,bridge=$NET_BRIDGE,ip=dhcp \
  -features nesting=1,fuse=1,keyctl=1,mount=1 \
  -password $PASSWORD \
  -unprivileged 0 \
  -onboot 1

pct start $NEXTID
echo "🚀 Đã tạo và khởi động container $NEXTID ($HOSTNAME)"

# Đẩy script cài Kavita vào LXC
INSTALL_SCRIPT="/root/kavita_install_inner.sh"

pct exec $NEXTID -- bash -c "apt update && apt install -y curl"

pct exec $NEXTID -- bash -c "curl -fsSL https://raw.githubusercontent.com/fevirtus/proxmox/main/kavita/kavita_inner.sh -o $INSTALL_SCRIPT"
pct exec $NEXTID -- bash -c "chmod +x $INSTALL_SCRIPT && $INSTALL_SCRIPT"

echo "✅ Hoàn tất! Truy cập Kavita tại: http://<IP-LXC>:5000"