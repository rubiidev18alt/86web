# 86Web

**86Web** is a web-based management interface for [86Box](https://86box.net) PC emulation — inspired by VMware ESXi — that lets you create, configure, start/stop, and interact with vintage PC virtual machines directly in your browser.

---

## TL;DR — Quick Start

```bash
git clone <repo> 86web && cd 86web
sudo useradd -r -g 86web -s /usr/sbin/nologin 86web  # create service user (groupadd -r 86web first)
cp .env.example .env          # set PUID/PGID to match 86web user, set ADMIN_PASSWORD
sudo bash scripts/init-data.sh  # create data directories with correct ownership
docker compose up -d          # build and start
```

Open `http://localhost` — log in as `admin` / `changeme` (or whatever you set).

> **Minimum requirements:** Docker + Compose v2, Linux host (amd64 or arm64), kernel with bridge/TAP support.

### Android / Termux Quick Start

86Web now includes an Android host mode for Termux/proot. It runs the backend, runner, and frontend directly on Android without Docker:

```bash
pkg update
pkg install git python nodejs-lts clang make rust binutils iproute2
termux-setup-storage

git clone https://github.com/rubiidev18alt/86web.git
cd 86web
bash scripts/android-86web.sh setup
bash scripts/android-86web.sh start
```

Open `http://127.0.0.1:8086` on the Android device. The helper also prints a same-Wi-Fi URL for other devices.

Android mode is best for testing, UI work, and lightweight local hosting. Full 86Box VM networking/TAP support still depends on the Android device, kernel, root/container setup, and whether a working 86Box binary exists for that userspace. See [`docs/android.md`](docs/android.md).

---

## Features

- **Full VM Management** — Create, configure, start, stop, reset, and delete virtual machines running any operating system that 86Box supports (DOS, Windows 3.x–XP, OS/2, Linux, etc.)
- **Complete 86Box Configuration** — Machine type, CPU, memory, video, sound, network, storage controllers, drives, ports, and per-device IRQ/DMA settings — all from the browser
- **Browser VNC Console** — Live display via noVNC over WebSocket with a tabbed multi-VM view; interact with VMs in real time without any client software
- **Browser Audio** — Real-time audio streaming from each VM to your browser via WebM/Opus — hear Sound Blaster, Adlib, and GUS output with no plugins or extra software required; configurable buffer for latency vs. smoothness trade-off
- **VM Groups** — Organise VMs into colour-coded groups for easy management
- **Automatic Group Networking** — Enable networking on a group and every VM in it is automatically connected to a shared private LAN via Linux bridge + TAP devices; VMs can communicate at Layer 2 with zero manual network configuration — just start them and they're connected. No internet access by design; ideal for retro LAN gaming, file sharing, or multi-machine setups
- **Dashboard** — Real-time CPU, memory, disk stats; per-user and system-wide VM counts
- **Multi-user Auth** — Local accounts + LDAP, admin/user roles, per-user VM and storage quotas
- **Media Library** — Column-view browser for your disk images (upload, delete, rename, move); read-only shared library mount for a central image collection
- **Auto-update** — Downloads the latest 86Box binary and ROM files on startup; manual trigger from Settings
- **VM Auto-Shutdown** — Optionally stop VMs that have been running longer than a configurable time limit (env var `VM_AUTO_SHUTDOWN_MINUTES`) — useful for shared installs
- **SSL/TLS Support** — Optional HTTPS with automatic HTTP-to-HTTPS redirect; bring your own certificates (e.g. Let's Encrypt)
- **macvlan Support** — Give 86Web its own IP on your LAN; no port forwarding needed
- **Dark & Light Mode**
- **Fully Dockerised** — `docker compose up` and you're running
- **Android host mode** — Run a local 86Web stack from Termux/proot for Android testing and lightweight browser hosting

---

## More docs

The original full README content is still supported by the Docker stack. Android-specific setup is documented in [`docs/android.md`](docs/android.md).
