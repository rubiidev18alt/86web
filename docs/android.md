# Running 86Web on Android

86Web's normal deployment is Docker Compose on Linux. Android is different: stock Android does not provide the normal Linux service-user, bridge, TAP, and container networking setup that 86Web expects from the default Compose stack.

This repo includes an Android/Termux host mode for testing and lightweight local use.

## What this mode does

`scripts/android-86web.sh` starts a local three-process stack:

- Backend FastAPI server on `127.0.0.1:8000`
- Runner FastAPI server on `127.0.0.1:8001`
- Frontend Vite server on `0.0.0.0:8086`

The frontend proxies:

- `/api` to the backend
- `/vnc` to the runner WebSocket endpoint
- `/vms` to the runner audio/media endpoint

This means the Android browser can open one URL and still reach the API, VNC WebSocket proxy, and audio routes.

## What this mode does not guarantee

This is not the same as Docker on a normal Linux host.

Limitations to expect:

- Full bridge/TAP group networking may not work on stock Android.
- Rootless Android cannot normally create the same network devices the Docker runner uses.
- A working 86Box binary still has to exist for your device/userspace. Most Android devices are ARM64, so the Android profile defaults `BOX86_ARCH=aarch64`.
- Performance will depend heavily on the phone/tablet CPU and thermal throttling.
- If VM start fails, the web UI can still run, but the runner may not be able to launch 86Box on that Android environment.

For reliable heavy use, use a Linux PC/server. For experimenting from Android, this mode is useful.

## Termux setup

Install Termux from F-Droid, not the outdated Play Store build.

In Termux:

```bash
pkg update
pkg install git python nodejs-lts clang make rust binutils iproute2
termux-setup-storage
```

Clone your fork:

```bash
git clone https://github.com/rubiidev18alt/86web.git
cd 86web
```

Create the Android environment:

```bash
bash scripts/android-86web.sh setup
```

Start it:

```bash
bash scripts/android-86web.sh start
```

Open this on the Android device:

```text
http://127.0.0.1:8086
```

The helper also prints a same-Wi-Fi URL such as:

```text
http://192.168.1.50:8086
```

Use that from another device on the same network.

Default login:

```text
admin / changeme
```

Change `ADMIN_PASSWORD` and `APP_SECRET_KEY` in `.env.android` before using it for anything serious.

## Commands

```bash
bash scripts/android-86web.sh setup      # install Python/Node deps and create .env.android
bash scripts/android-86web.sh start      # start backend, runner, and frontend
bash scripts/android-86web.sh stop       # stop all Android-hosted processes
bash scripts/android-86web.sh restart    # restart all Android-hosted processes
bash scripts/android-86web.sh status     # show process status and URLs
bash scripts/android-86web.sh logs       # tail logs
bash scripts/android-86web.sh doctor     # check common requirements
```

## Data layout

Android mode uses separate paths so it does not fight the Docker setup:

```text
.env.android
android/
android/logs/
android/pids/
data-android/
library/
```

`data-android/` stores the Android mode database, VM metadata, ROM cache, uploaded images, and media pools.

## Ports

Defaults:

```text
Frontend: 8086
Backend:  8000
Runner:   8001
```

Override them like this:

```bash
HOST_PORT=8090 BACKEND_PORT=8100 RUNNER_PORT=8101 bash scripts/android-86web.sh start
```

## Proot Ubuntu option

If plain Termux Python packages fight you, use an Ubuntu proot and run the same helper inside it.

Example with `proot-distro`:

```bash
pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu
apt update
apt install -y git python3 python3-venv python3-pip nodejs npm iproute2 build-essential curl

git clone https://github.com/rubiidev18alt/86web.git
cd 86web
bash scripts/android-86web.sh setup
bash scripts/android-86web.sh start
```

You still open the frontend from Android's browser at `http://127.0.0.1:8086`.

## Practical recommendation

Use Android mode for:

- UI development
- Backend API testing
- Browsing/managing data
- Seeing how far your device can get with the runner

Use normal Docker/Linux mode for:

- dependable 86Box VM hosting
- TAP/bridge networking
- multiple running VMs
- serious retro LAN setups
