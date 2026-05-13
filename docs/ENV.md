# Environment Variables

This document is auto-generated from `.env.example`. Last updated: 2026-05-13

<!-- AUTO-GENERATED START -->

## Multi-Instance Configuration

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `COMPOSE_PROJECT_NAME` | Yes | Docker Compose project name (namespaces containers, volumes, networks) | `cc-docker` |
| `PORT_BASE` | Yes | Port base for host bindings (41xxx) | `41` |
| `VOLUME_CHECK_MODE` | No | Volume check mode (interactive, auto-fresh, auto-adopt, skip) | `interactive` |
| `VOLUME_ADOPT_FROM` | No | Source project for auto-adopt mode | `cc-docker` |
| `DOCKER_GID` | No | Docker group GID on host (auto-detected, for DinD mode) | `496` |

## Container Configuration

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `DEV_USER` | No | Username inside container (default: dev, UID/GID 1000) | `dev` |

## Claude Authentication

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | No | Claude Code API Key for headless authentication | (key) |
| `ANTHROPIC_BASE_URL` | No | Anthropic endpoint override for proxies | (url) |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | No | Override default Haiku model | (model) |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | No | Override default Sonnet model | (model) |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | No | Override default Opus model | (model) |

## iOS Development (Host Bind Mount)

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `HOST_WORKSPACE_PATH` | No | Host workspace path for iOS development bind mount | `./workspace` |

## Host Mounts

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `SSH_AUTH_SOCK` | No | SSH Agent Socket (Mac/Linux auto-detected) | (socket path) |
| `HOME` | No | Host home directory (for mounting .gitconfig) | (path) |
| `CLAUDE_MARKETPLACE_PATH` | No | Local marketplace path (absolute) | `/path/to/marketplace` |

<!-- AUTO-GENERATED END -->

## Usage

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
# Edit .env with your values
```

## Port Convention

All host ports use `${PORT_BASE}xxx` pattern (default `41xxx`):

| Service | Container Port | Host Port (default 41) |
|---------|----------------|------------------------|
| React/Express | 3000 | 41300 |
| Vite | 5173 | 41517 |
| Go/Generic | 8080 | 41808 |
| noVNC | 6080 | 41608 |

For multi-instance setup, use `PORT_BASE=42` → 42xxx ports.
