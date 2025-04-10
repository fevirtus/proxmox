# 🚀 Kavita Setup Script for Proxmox LXC

This script installs:
- Docker & Docker Compose
- Rclone (for Google Drive 2-way sync)
- Kavita (self-hosted ebook/comic reader)

📚 Library is mounted from Google Drive using `rclone mount`.

---

## 🧑‍💻 How to Use

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fevirtus/proxmox/main/kavita/kavita.sh)"
```

## 📂 Mount Location
Local Path | Description
--- | ---
/mnt/gdrive/books | Mounted Google Drive folder
/opt/kavita | Kavita + config files

## 🌐 Access Kavita

http://<your-proxmox-lxc-ip>:5000

## 📦 Requirements

- Proxmox LXC (Ubuntu 22.04+)
- Google Drive API key
- Rclone config




