# nas-base

Docker image stack for running Claude Code CLI and OpenClaw on a Ugreen DXP2800GT NAS.

## Image hierarchy

```
node:slim
  └── nas-base        (Claude Code CLI)
        └── media-base      (+ ffmpeg, exiftool)
              └── claude-interactive   (CMD: claude)

ghcr.io/openclaw/openclaw
  └── openclaw-claude  (+ Claude Code CLI)
```

## Storage layout

The DXP2800GT has an NVMe M.2 and HDD bays. Put fast-access app data on NVMe and bulk files on HDD.

| What | Drive | Why |
|------|-------|-----|
| Docker data root (`/var/lib/docker`) | NVMe | Image layers, named volumes — random I/O heavy |
| OpenClaw workspace (`WORKSPACE_PATH`) | NVMe | Active working directory; many small file ops |
| OpenClaw compile cache (inside `claude-auth` volume) | NVMe | Written by Docker, lives under Docker data root |
| Main file library (`FILES_PATH`) | HDD | Large media/docs — bulk capacity |
| Media path for claude interactive (`MEDIA_PATH`) | HDD | Large files, not latency-sensitive |

**Move Docker's data root to NVMe in UGOS:**
UGOS > Container Manager > Settings > Docker data path → set to a folder on your NVMe volume (e.g. `/volume2/docker`).

Typical volume mount points on UGOS:
- `/volume1` — HDD storage pool
- `/volume2` — NVMe storage pool (or whichever you labeled it)

## Prerequisites

- Docker / Container Manager enabled in UGOS
- SSH access to the NAS
- `git` available (install via UGOS package manager or run inside a container)

## Setup

### 1. Clone the repo

SSH into the NAS and clone to the NVMe volume:

```bash
cd /volume2
git clone <repo-url> nas-base
cd nas-base
```

### 2. Configure environment files

Copy the examples and fill in your values:

```bash
cp claude/.env.example claude/.env
cp openclaw/.env.example openclaw/.env
```

Key fields to set for NAS deployment:

| File | Field | NAS value |
|------|-------|-----------|
| `claude/.env` | `MEDIA_PATH` | `/volume1/media` |
| `openclaw/.env` | `OPENCLAW_GATEWAY_PASSWORD` | a strong password |
| `openclaw/.env` | `WORKSPACE_PATH` | `/volume2/openclaw-workspace` |
| `openclaw/.env` | `FILES_PATH` | `/volume1` |

The default dev values in `.env.example` point to `dev-volumes/` for local use.

### 3. Build images

```bash
cd claude
docker-compose build nas-base
docker-compose build media-base
docker-compose build claude
```

```bash
cd ../openclaw
docker-compose build openclaw-gateway
```

### 4. Authenticate Claude

Run this once — auth is stored in the `claude-auth` Docker named volume and shared by all services:

```bash
cd claude
./startup.sh --media /volume1/media
# Inside the container, run:
claude auth login
# Follow the browser link, then exit
```

Auth persists across container restarts. You only need to redo this if the `claude-auth` volume is deleted.

## Usage

### Claude interactive

Starts (or re-attaches to) a persistent container with your media directory mounted:

```bash
cd claude
./startup.sh --media /volume1/media
```

Options:
- `--no-build` — skip image builds if already up to date
- `--media <path>` — override `MEDIA_PATH`

The container (`claude-interactive`) stays running between sessions. To stop it:

```bash
docker rm -f claude-interactive
```

### OpenClaw gateway

Exposes a Claude-powered file gateway on port 18789:

```bash
cd openclaw
./startup.sh
```

Options:
- `--no-build` — skip image build
- `--workspace <path>` — override `WORKSPACE_PATH`
- `--files <path>` — override `FILES_PATH`
- `--auth` — re-run Claude auth inside the gateway container

**First-time onboarding** (must be done in a real TTY, not a detached session):

```bash
cd openclaw
docker-compose run --rm -it openclaw-gateway openclaw onboard --mode local
```

Gateway runs in the foreground. To run it as a background service, configure it as an autostart container in UGOS Container Manager.

## Named volumes

| Volume | Contents | Shared by |
|--------|----------|-----------|
| `claude-auth` | Claude credentials, config, compile cache | `claude-interactive`, `openclaw-gateway` |

The `claude-auth` volume is created by `claude/docker-compose.yml` and referenced as external by `openclaw/docker-compose.yml`. Always bring up the `claude` stack at least once before `openclaw`.
