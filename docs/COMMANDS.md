# Commands Reference

This document is auto-generated from `Makefile`. Last updated: 2026-06-30

<!-- AUTO-GENERATED START -->

## Build Commands

| Command | Description |
|---------|-------------|
| `make init` | Initialize environment (copy .env.example to .env if missing) |
| `make build` | Build core image (all stacks) |
| `make build-slim` | Build slim image (Node + Go only) |
| `make build-all` | Build all images including profiles |
| `make build-no-cache` | Build core image without cache |
| `make GPU=true build` | Build with NVIDIA GPU support |

## Run Commands

| Command | Description |
|---------|-------------|
| `make up` | Start core environment (with volume check) |
| `make down` | Stop all services (volumes persist) |
| `make restart` | Restart all services |
| `make DIND=true up` | Start with Docker-in-Docker enabled |
| `make DEBUG=true up` | Start with debugger support (SYS_PTRACE) |

## Profile Commands

| Command | Description |
|---------|-------------|
| `make solana-up` | Start with Solana profile |
| `make mobile-up` | Start with Mobile profile (Android) |
| `make host-bind-up` | Start with host workspace bind mount (core only) |
| `make host-bind-mobile-up` | Start with host bind + Mobile profile (for iOS dev) |
| `make host-bind-solana-up` | Start with host bind + Solana profile |
| `make all-up` | Start everything |

## Interactive Commands

| Command | Description |
|---------|-------------|
| `make shell` | Open bash shell in cc-docker |
| `make claude` | Launch Claude Code CLI |
| `make login` | Run Claude OAuth login |
| `make claude-reset` | Reset Claude Code to baked version (removes runtime install) |
| `make gh-auth` | Run 'gh auth login' interactively inside container |
| `make gh-status` | Show GitHub CLI auth status |
| `make shell-solana` | Open shell in Solana container |
| `make shell-mobile` | Open shell in Mobile container |

## Plugin Commands

| Command | Description |
|---------|-------------|
| `make install-plugins` | Register marketplace and sync plugin content |
| `make sync-plugins` | Manually trigger plugin content sync |
| `make reset-plugins` | Clear stale plugin state for re-sync |

## Browser Commands (noVNC + Playwright)

| Command | Description |
|---------|-------------|
| `make browser` | Open noVNC visual browser in host browser |
| `make browser-start` | Start noVNC visual browser inside container |
| `make browser-stop` | Stop visual browser processes |
| `make browser-test TEST=path` | Run Playwright tests |
| `make browser-screenshot URL=https://example.com` | Take a Playwright screenshot |

## Status & Diagnostics

| Command | Description |
|---------|-------------|
| `make status` | Show running containers and volumes |
| `make logs` | Follow logs for cc-docker |
| `make health` | Run health check on all installed runtimes |

## Cleanup Commands

| Command | Description |
|---------|-------------|
| `make clean` | Stop containers and remove images (volumes persist) |
| `make nuke` | Remove EVERYTHING (containers, volumes, images) |

## Backup & Restore

| Command | Description |
|---------|-------------|
| `make backup` | Backup project volume to timestamped tar.gz |
| `make restore FILE=path` | Restore project volume from backup |
| `make backup-list` | List all available backups |
| `make backup-clean` | Delete backups older than 30 days |
| `make backup-enc` | Encrypted backup (openssl AES-256) |
| `make restore-enc FILE=path` | Restore from encrypted backup |

## Volume Management

| Command | Description |
|---------|-------------|
| `make volume-check` | Pre-flight volume check before starting |
| `make volume-status` | Show volume status and detected orphans |
| `make volume-adopt FROM=project` | Adopt orphan volumes |

<!-- AUTO-GENERATED END -->

## Build Options

| Option | Usage | Description |
|--------|-------|-------------|
| `GPU=true` | `make GPU=true build` | Build with NVIDIA CUDA support (Linux/WSL2 only) |
| `DIND=true` | `make DIND=true up` | Enable Docker-in-Docker mode |
| `DEBUG=true` | `make DEBUG=true up` | Enable debugger support (SYS_PTRACE) |
| `PORT_BASE=42` | `make PORT_BASE=42 up` | Override port base (default: 41) |
