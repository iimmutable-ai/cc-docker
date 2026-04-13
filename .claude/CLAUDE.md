# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dockerized development environment running Claude Code CLI inside Docker. Provides Node.js, .NET, Go, Rust runtimes with built-in browser (Playwright + Chromium + noVNC), and optional Solana and Mobile profiles. Named volumes store code and auth persistently.

## Commands

```bash
make init               # Initialize .env from .env.example (first-time setup)
make build              # Build core image (Node + .NET + Go + Rust)
make build-slim         # Build with Node + Go only (skip .NET, Rust)
make build-all          # Build all profiles including Solana + Mobile
make build-no-cache     # Full rebuild without layer cache
make GPU=true build     # Build with NVIDIA CUDA support (Linux/WSL2 only)

make up                 # Start core environment (with volume check)
make down               # Stop all services (volumes persist)
make solana-up          # Start with Solana profile
make mobile-up          # Start with Mobile profile
make all-up             # Start everything

# Host Bind Mount (iOS Development on macOS)
make host-bind-up       # Start with host bind mount (core only)
make host-bind-mobile-up # Start with host bind + Mobile profile (for iOS dev)
make host-bind-solana-up # Start with host bind + Solana profile

make shell              # Open bash in docker-claude
make claude             # Launch Claude Code CLI
make login              # Run Claude OAuth login flow
make shell-solana       # Shell in Solana container
make shell-mobile       # Shell in Mobile container

make browser            # Open noVNC visual browser in host browser
make browser-start      # Start noVNC visual browser inside container
make browser-stop       # Stop visual browser processes
make browser-test TEST= # Run Playwright tests
make browser-screenshot URL= # Take a Playwright screenshot

make health             # Verify all runtimes, auth, Docker socket
make status             # Show containers, volumes, image sizes

make volume-status      # Show volume status and detected orphans
make volume-adopt FROM= # Adopt orphan volumes from project 'FROM'
make volume-check       # Run pre-flight volume check manually

make clean              # Remove containers + images (volumes persist)
make nuke               # Remove EVERYTHING including volumes (prompts)

make backup             # Backup project volume to ./backups/
make restore FILE=...   # Restore from backup (stops containers)
```

## Multi-Instance Configuration

This project supports running multiple isolated instances simultaneously. Each instance has unique:
- **Container names** — prefixed by `COMPOSE_PROJECT_NAME`
- **Volume names** — prefixed by `COMPOSE_PROJECT_NAME`
- **Ports** — configurable via `PORT_BASE`

### Setting Up a Second Instance

```bash
# 1. Copy project to new location
cp -r /path/to/docker-claude /path/to/trial-claude
cd /path/to/trial-claude

# 2. Create .env with unique settings
cp .env.example .env
# Edit .env:
#   COMPOSE_PROJECT_NAME=trial-claude
#   PORT_BASE=42

# 3. Build and start
make build
make up
```

### Resource Naming

| Resource | First Instance | Second Instance |
|----------|---------------|-----------------|
| Project name | `docker-claude` | `trial-claude` |
| Container | `docker-claude-docker-claude-1` | `trial-claude-docker-claude-1` |
| Projects volume | `docker-claude_vol-projects` | `trial-claude_vol-projects` |
| Auth volume | `docker-claude_vol-claude-auth` | `trial-claude_vol-claude-auth` |
| Ports | 41xxx | 42xxx |

## iOS Development Workflow (macOS)

For iOS development with Flutter, use the host bind mount workflow:
- **Edit code in container** → `make shell-mobile`
- **Build/debug on host** → `flutter run -d iPhone` (uses host Xcode + Simulator)

### Setup

```bash
# 1. Start with host bind mount (creates ./workspace if missing)
make host-bind-mobile-up

# 2. Create Flutter app inside container
make shell-mobile
cd /workspace
flutter create my_app

# 3. On Mac host, run iOS debugging
cd ./workspace/my_app
flutter run -d iPhone
```

### Key Points

- `docker-compose.host-bind.yml` replaces named volume with host bind mount
- `HOST_WORKSPACE_PATH` defaults to `./workspace` (configurable in `.env`)
- Auth volume still uses named volume (credentials shouldn't sync to host)
- Named volume mode remains default — host bind only when explicitly used

## Architecture

### Conditional Runtime Installation

The Dockerfile uses build args to conditionally install runtimes:

```dockerfile
ARG INCLUDE_NODE=true
ARG INCLUDE_DOTNET=true
ARG INCLUDE_GOLANG=true
ARG INCLUDE_RUST=true
ARG INCLUDE_BROWSER=true
ARG INCLUDE_GPU=false
```

Each runtime block checks its arg before installing. This allows slim builds via:
```bash
docker compose build --build-arg INCLUDE_DOTNET=false --build-arg INCLUDE_RUST=false
```

### Volume Architecture

Two named volumes (fully virtualized, no host bind mounts), prefixed by `COMPOSE_PROJECT_NAME`:
- `{project}_vol-projects` → `/workspace` — code, dependencies, caches
- `{project}_vol-claude-auth` → `/home/dev/.claude` — OAuth credentials

Default (COMPOSE_PROJECT_NAME=docker-claude):
- `docker-claude_vol-projects` → `/workspace`
- `docker-claude_vol-claude-auth` → `/home/dev/.claude`

Files enter/exit via:
- `git clone` inside container
- `docker cp` for ad-hoc transfers
- Backup tarball exports (`make backup`)

### Profile System

Optional profiles extend the base image:
- `--profile solana` → Dockerfile.solana (Solana CLI + Anchor + Rust BPF target)
- `--profile mobile` → Dockerfile.mobile (Android SDK + Flutter + React Native CLI)

Both inherit from `docker-claude:latest` via `ARG BASE_IMAGE=docker-claude`.

### Port Convention

All host ports use `${PORT_BASE}xxx` pattern (default `41xxx`) to avoid conflicts:
- Container 3000 → Host `${PORT_BASE}300` (default: 41300) — React/Express
- Container 5173 → Host `${PORT_BASE}517` (default: 41517) — Vite
- Container 8080 → Host `${PORT_BASE}808` (default: 41808) — Go/Generic
- Container 6080 → Host `${PORT_BASE}608` (default: 41608) — noVNC visual browser

For multi-instance setup, use `PORT_BASE=42` for second instance → 42xxx ports.

Map defined in docker-compose.yml `ports:` section with `${PORT_BASE:-41}` substitution.

### Entrypoint Logic

`entrypoint.sh` handles:
1. NVM initialization (sources `/usr/local/nvm/nvm.sh`)
2. SSH agent forwarding (Mac: socket mount; Windows: key mount + local agent)
3. Claude auth detection (API key or OAuth credentials)
4. Runtime status display

All shells must source NVM first for Node commands:
```bash
. /usr/local/nvm/nvm.sh
```

## Key Files

| File | Purpose |
|------|---------|
| `.env.example` | Template for environment variables (copy to `.env`) |
| `.env` | Active configuration (git-ignored, includes `COMPOSE_PROJECT_NAME`, `PORT_BASE`, `VOLUME_CHECK_MODE`, `HOST_WORKSPACE_PATH`) |
| `.volume-state` | Per-folder volume tracking (git-ignored, auto-generated) |
| `Dockerfile` | Core image with conditional runtime build args |
| `docker-compose.yml` | Service definitions, volumes, ports, profiles (uses variable substitution) |
| `docker-compose.host-bind.yml` | Host bind mount override for iOS development |
| `Makefile` | Primary interface — all commands via `make` |
| `scripts/volume-check.sh` | Volume detection, orphan detection, and migration |
| `scripts/entrypoint.sh` | Container startup: runtime init, auth check |
| `config/.bashrc` | Shell config inside container (aliases, PATH) |
| `config/novnc-startup.sh` | noVNC startup script for visual browser |
| `config/starship.toml` | Starship prompt config (Catppuccin Powerline) |
| `devcontainer.json` | VS Code Dev Container integration |
| `Dockerfile.solana` | Solana profile (extends base) |
| `Dockerfile.mobile` | Mobile profile (Android + Flutter + RN) |

## Modifying the Image

When adding new runtime or tool:

1. Add build arg in Dockerfile: `ARG INCLUDE_NEW=true`
2. Add conditional install block following existing pattern
3. Add PATH/env setup in Dockerfile `ENV` section
4. Update `config/.bashrc` with conditional PATH export
5. Update `entrypoint.sh` runtime status display
6. Update `devcontainer.json` extensions if VS Code relevant
7. Update README.md documentation

## Cross-Platform Notes

- Mac: SSH agent forwarding via `SSH_AUTH_SOCK` mount
- Windows: Keys mounted from `%USERPROFILE%\.ssh`, entrypoint starts local agent
- GPU: Only works on Linux/WSL2 (not macOS)
- Line endings: `.gitattributes` enforces LF, setup scripts sanitize CRLF