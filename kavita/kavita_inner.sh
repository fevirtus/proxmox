#!/bin/bash

set -e

echo "🚀 Bắt đầu cài đặt Docker + Rclone + Kavita..."

# 1. Cập nhật hệ thống
apt update && apt upgrade -y

# 2. Cài đặt Docker
echo "🐳 Đang cài Docker..."
apt install -y curl ca-certificates gnupg lsb-release apt-transport-https software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose

# 3. Cài đặt Rclone
echo "🔗 Đang cài Rclone..."
curl https://rclone.org/install.sh | bash

# 4. Tạo remote Google Drive (hướng dẫn thủ công)
echo "🌐 Vui lòng cấu hình kết nối Google Drive (sẽ cần trình duyệt)"
rclone config

# 5. Mount Google Drive
echo "📂 Mount Google Drive vào /mnt/gdrive/books"
mkdir -p /mnt/gdrive/books

# Lưu service systemd để mount tự động sau reboot
echo "🛠️ Tạo systemd service cho rclone mount..."

cat <<EOF > /etc/systemd/system/rclone-gdrive-books.service
[Unit]
Description=Rclone Mount Google Drive to /mnt/gdrive/books
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/rclone mount gdrive:/Books /mnt/gdrive/books \\
  --allow-other \\
  --dir-cache-time 72h \\
  --vfs-cache-mode full \\
  --vfs-cache-max-size 2G \\
  --vfs-read-chunk-size 64M \\
  --poll-interval 15s \\
  --umask 002

ExecStop=/bin/fusermount -u /mnt/gdrive/books
Restart=on-failure
User=root

[Install]
WantedBy=default.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now rclone-gdrive-books

# 6. Tạo thư mục Kavita
echo "📁 Tạo thư mục Kavita..."
mkdir -p /opt/kavita/config

# 7. Tạo file docker-compose.yml
echo "📦 Tạo docker-compose.yml..."
cat <<EOF > /opt/kavita/docker-compose.yml
version: "3.3"
services:
  kavita:
    image: kizaing/kavita:latest
    container_name: kavita
    ports:
      - "5000:5000"
    volumes:
      - ./config:/kavita/config
      - /mnt/gdrive/books:/kavita/manga
    restart: unless-stopped
EOF

# 8. Khởi động Kavita
cd /opt/kavita
docker-compose up -d

echo "✅ Đã hoàn tất cài đặt!"
echo "📚 Truy cập Kavita tại: http://<IP-LXC>:5000"