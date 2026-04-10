# Docker Claude — Dockerized Development Environment

A fully virtualized, cross-platform development environment running Claude Code inside Docker. Supports TypeScript/JavaScript, Node.js, Express, React, React Native, Vue 3, ASP.NET Core, C#, Go, Rust, Solana, Flutter, and more.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     Docker Compose                           │
│                    Project: ${COMPOSE_PROJECT_NAME}          │
│                                                              │
│  SERVICES                                                    │
│  ├── docker-claude          (default)  Core dev environment  │
│  ├── docker-claude-solana   (profile)  Solana + Anchor       │
│  └── docker-claude-mobile   (profile)  Android SDK/Flutter/RN│
│                                                              │
│  VOLUMES (prefixed by project name)                          │
│  ├── {project}_vol-projects  →  /workspace  (code+deps)     │
│  └── {project}_vol-claude-auth → ~/.claude  (auth)          │
│                                                              │
│  IMAGE (conditional install via build args)                   │
│  Ubuntu 24.04 LTS base + Docker CLI + core utils             │
│  + nvm + Node LTS + pnpm/yarn/tsx          (INCLUDE_NODE)    │
│  + .NET 8 & 9 SDK                          (INCLUDE_DOTNET)  │
│  + Go 1.23 + gopls + delve                 (INCLUDE_GOLANG)  │
│  + rustup + stable + rust-analyzer/clippy  (INCLUDE_RUST)    │
│  + Playwright + Chromium + noVNC/Xvfb      (INCLUDE_BROWSER) │
│  + NVIDIA CUDA runtime                     (INCLUDE_GPU)     │
│  + Claude Code CLI + non-root user + SSH/Git                 │
│  + Yazi + Lazygit + Starship (terminal tools)                │
└──────────────────────────────────────────────────────────────┘
```

## Getting Started

### Step 0 — Get docker-claude

```bash
git clone https://github.com/iimmutable/docker-claude.git
cd docker-claude
```

### Step 1 — Install Docker Desktop

| Platform | Download | Notes |
|---|---|---|
| Mac | [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/) | Choose Apple Silicon (M-series) or Intel. Check with `uname -m` |
| Windows | [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/) | Requires WSL2 backend enabled |

After installing, launch Docker Desktop and wait for the whale icon to stop animating. Verify:

```bash
docker --version          # Should show a version number
docker compose version    # Should show a version number
```

### Step 2 — Configure

```bash
cp .env.example .env
```

Edit `.env`:

```bash
# Multi-Instance Configuration (REQUIRED for parallel instances)
COMPOSE_PROJECT_NAME=docker-claude    # Change for each instance (e.g., trial-claude)
PORT_BASE=41                          # Use 42 for second instance, 43 for third

# Auth (pick one):
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here   # Option A: API key
# Or leave empty and run `make login` later     # Option B: OAuth

# Optional — proxy or local LLM gateway (leave blank to use api.anthropic.com):
# ANTHROPIC_BASE_URL=https://your-proxy.example.com

# Optional — pin specific model versions (leave blank for Claude Code defaults):
# ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5-20251001
# ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6
# ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6

# Mac/Linux only (run these commands to get the values):
SSH_AUTH_SOCK=       # paste output of: echo $SSH_AUTH_SOCK
HOME=                # paste output of: echo $HOME

# Optional — local Claude Code plugin marketplace:
CLAUDE_MARKETPLACE_PATH=/path/to/your/marketplace
```

<!-- AUTO-GENERATED: from .env.example — do not edit this section manually -->
#### Environment Variable Reference

| Variable | Required | Description |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | No* | Docker Compose project name (namespaces containers, volumes, networks). Change for each parallel instance. Default: `docker-claude`. |
| `PORT_BASE` | No | Port prefix for host bindings. Default: `41` → 41xxx ports. Use `42` for second instance, `43` for third, etc. |
| `VOLUME_CHECK_MODE` | No | Volume check mode: `interactive` (prompt), `auto-fresh` (create new), `auto-adopt` (copy from source), `skip` (no checks). Default: `interactive`. |
| `VOLUME_ADOPT_FROM` | No | Source project for auto-adopt mode. Example: `docker-claude`. Only used when `VOLUME_CHECK_MODE=auto-adopt`. |
| `ANTHROPIC_API_KEY` | No* | API key for headless auth. Leave empty and use `make login` for OAuth. |
| `ANTHROPIC_BASE_URL` | No | Override the Anthropic API endpoint (e.g. for proxies or local LLM gateways). |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | No | Pin a specific Haiku model version. Leave empty for Claude Code defaults. |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | No | Pin a specific Sonnet model version. Leave empty for Claude Code defaults. |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | No | Pin a specific Opus model version. Leave empty for Claude Code defaults. |
| `DEV_USER` | No | Username inside the container (default: `dev`). Set to match your host username or any custom name. Requires rebuild. |
| `SSH_AUTH_SOCK` | No | SSH agent socket path (Mac/Linux). Run `echo $SSH_AUTH_SOCK` to get value. |
| `HOME` | No | Host home directory for mounting `.gitconfig` (Mac/Linux). Run `echo $HOME`. |
| `CLAUDE_MARKETPLACE_PATH` | No | Absolute path to a local Claude Code plugin marketplace folder on your host. |
| `USERPROFILE` | No | Windows only. Set to `%USERPROFILE%` path (e.g. `C:\Users\YourName`). |

*One of `ANTHROPIC_API_KEY` or OAuth (`make login`) is required to use Claude Code. `COMPOSE_PROJECT_NAME` and `PORT_BASE` must be changed when running multiple instances simultaneously.
<!-- AUTO-GENERATED END -->

### Step 3 — Build & Start

**Mac / Linux:**

```bash
chmod +x scripts/setup.sh scripts/entrypoint.sh
make build            # First build: ~10-20 min (cached after that)
make up
```

**Windows (PowerShell):**

```powershell
.\scripts\setup.ps1
```

### Step 4 — Verify

```bash
make health
```

Expected output:

```
=== Runtime Health Check ===

Node.js:  v24.x.x
npm:      11.x.x
.NET:     9.x.x
Go:       go version go1.23.x
Rust:     rustc 1.x.x
Docker:   Docker version 2x.x.x
Git:      git version 2.x.x
Claude:   2.1.77 (Claude Code)

=== Auth Status ===
API Key: configured            # or: Auth: NOT CONFIGURED

=== Docker Socket ===
Socket: not mounted (default for security)

Browser:  1.x.x
Claude Code: Global settings loaded
Claude Code: Local marketplace mounted (N plugin(s))
```

### Step 5 — Authenticate (if using OAuth)

Skip this if you set `ANTHROPIC_API_KEY` in `.env`.

```bash
make login
```

Follow the URL shown in the terminal and complete login in your browser.

### Step 6 — Register Marketplace (if using plugins)

Skip this if you don't have a local marketplace.

```bash
make shell
claude plugin marketplace add /etc/claude-code/marketplace
```

### Step 7 — Start Coding

```bash
# Launch Claude Code directly
make claude

# Or open a shell, clone a project, then start Claude Code
make shell
cd /workspace
git clone git@github.com:your-org/your-project.git
cd your-project
claude
```

### Quick Reference

| What you want to do | Command |
|---|---|
| Initialize environment | `make init` |
| Start the environment | `make up` |
| Stop the environment | `make down` |
| Open a shell | `make shell` |
| Launch Claude Code | `make claude` |
| OAuth login | `make login` |
| Check runtime health | `make health` |
| Backup your projects | `make backup` |
| Encrypted backup | `make backup-enc` |
| Enable Docker-in-Docker | `make DIND=true up` |
| Enable debugger support | `make DEBUG=true up` |
| Copy file into container | `docker cp ./file.txt $(docker ps -q -f name=docker-claude):/workspace/` |
| Copy file out of container | `docker cp $(docker ps -q -f name=docker-claude):/workspace/file.txt ./` |
| View all commands | `make help` |
| Install plugins | `make install-plugins` |
| Sync plugins | `make sync-plugins` |
| Open visual browser | `make browser` |
| Start visual browser in container | `make browser-start` |
| Stop visual browser | `make browser-stop` |
| Run Playwright tests | `make browser-test TEST=path/to/test` |
| Take a screenshot | `make browser-screenshot URL=https://example.com` |
| Check volume status | `make volume-status` |
| Adopt orphan volumes | `make volume-adopt FROM=docker-claude` |

## Multi-Instance Setup

You can run multiple isolated instances of docker-claude simultaneously. Each instance has its own:
- **Containers** — separate container names
- **Volumes** — isolated code and auth storage
- **Ports** — configurable port range to avoid conflicts

### Volume Name Changes

When you change `COMPOSE_PROJECT_NAME` (e.g., setting up a second instance), Docker Compose creates NEW volumes with the new project prefix. Old volumes from the previous configuration remain as "orphans" — they're not deleted but are no longer associated with your project.

The `make up` command now includes a pre-flight volume check that:
- Detects if current project volumes exist
- Finds orphan volumes from other project names
- Prompts you to choose an action (fresh start, adopt data, or cancel)

### Volume Check Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `interactive` (default) | Prompt user when orphans detected | Normal usage |
| `auto-fresh` | Always create fresh volumes | CI/CD, automated environments |
| `auto-adopt` | Auto-adopt from specified project | Migration with known source |
| `skip` | Skip all checks | Trusted environments |

```bash
# Interactive mode (default)
make up

# Auto-fresh — create new volumes without prompting
VOLUME_CHECK_MODE=auto-fresh make up

# Auto-adopt — copy data from specific project
VOLUME_ADOPT_FROM=docker-claude make up

# Skip checks — proceed without prompts
VOLUME_CHECK_MODE=skip make up
```

### Volume Management Commands

| Command | Description |
|---|---|
| `make volume-status` | Show current volumes, orphans, and state file |
| `make volume-adopt FROM=x` | Adopt volumes from project 'x' |
| `make volume-check` | Run pre-flight check manually |

### Quick Setup

1. **Copy the project to a new location:**
   ```bash
   cp -r /path/to/docker-claude /path/to/trial-claude
   cd /path/to/trial-claude
   ```

2. **Create `.env` with unique project name and port base:**
   ```bash
   cp .env.example .env
   # Edit .env:
   #   COMPOSE_PROJECT_NAME=trial-claude
   #   PORT_BASE=42
   ```

3. **Build and start:**
   ```bash
   make build
   make up
   ```

### How It Works

| Setting | First Instance | Second Instance |
|---------|---------------|-----------------|
| `COMPOSE_PROJECT_NAME` | `docker-claude` | `trial-claude` |
| `PORT_BASE` | `41` | `42` |
| Container name | `docker-claude-docker-claude-1` | `trial-claude-docker-claude-1` |
| Project volume | `docker-claude_vol-projects` | `trial-claude_vol-projects` |
| Auth volume | `docker-claude_vol-claude-auth` | `trial-claude_vol-claude-auth` |
| Ports | 41xxx (41300, 41517, etc.) | 42xxx (42300, 42517, etc.) |

### Example: Running Two Instances

```bash
# Terminal 1 — Main instance
cd ~/projects/docker-claude
# .env: COMPOSE_PROJECT_NAME=docker-claude, PORT_BASE=41
make up
make claude

# Terminal 2 — Trial instance
cd ~/projects/trial-claude
# .env: COMPOSE_PROJECT_NAME=trial-claude, PORT_BASE=42
make up
make claude
```

Both instances run independently with separate codebases and authentication.

### Accessing Each Instance

| Service | Main Instance | Trial Instance |
|---------|--------------|----------------|
| React/Express | `localhost:41300` | `localhost:42300` |
| Vite | `localhost:41517` | `localhost:42517` |
| noVNC browser | `localhost:41608` | `localhost:42608` |
| Shell | `make shell` | `make shell` |

### Sharing Images Between Instances

Images are built once and tagged with the project name. To share the base image:

```bash
# Build in first instance
cd ~/projects/docker-claude
make build

# Reuse image in second instance (tag it)
docker tag docker-claude:latest trial-claude:latest

# Start second instance (skip build)
cd ~/projects/trial-claude
make up
```

### Backup Isolation

Backups are per-instance and include the project name:

```bash
# Main instance backup
docker-claude-backup_20260410_120000.tar.gz

# Trial instance backup
trial-claude-backup_20260410_120000.tar.gz
```

## Makefile Commands

The Makefile is the primary interface. Run `make help` to see all commands:

```bash
# Initialize
make init               # Create .env from .env.example if missing

# Build
make build              # Build core image (all stacks)
make build-slim         # Build with Node + Go only (skip .NET, Rust)
make build-all          # Build everything including Solana + Mobile profiles
make build-no-cache     # Full rebuild without Docker layer cache
make GPU=true build     # Build with NVIDIA GPU support

# Run
make up                 # Start core environment
make down               # Stop all services (volumes persist)
make restart            # Stop + start
make solana-up          # Start with Solana profile
make mobile-up          # Start with Mobile profile
make all-up             # Start everything

# Interactive
make shell              # Open bash shell in docker-claude
make claude             # Launch Claude Code CLI
make login              # Run Claude OAuth login
make shell-solana       # Open shell in Solana container
make shell-mobile       # Open shell in Mobile container

# Diagnostics
make health             # Check all runtimes, auth, Docker socket
make status             # Show containers, volumes, image sizes
make logs               # Follow docker-claude logs
make logs-all           # Follow all service logs

# Plugin Management
make install-plugins   # Register marketplace and sync plugin content
make sync-plugins     # Manually trigger plugin content sync from marketplace
make reset-plugins    # Clear stale plugin state for re-sync on next start

# Browser (noVNC + Playwright)
make browser           # Open noVNC visual browser in host browser
make browser-start     # Start noVNC visual browser inside container
make browser-stop      # Stop visual browser processes
make browser-test      # Run Playwright tests (usage: make browser-test TEST=path/to/test)
make browser-screenshot # Take a Playwright screenshot (usage: make browser-screenshot URL=https://example.com)

# Cleanup
make clean              # Remove containers + images (volumes persist)
make nuke               # ⚠️ Remove EVERYTHING including volumes

# Backup & Restore
make backup             # Backup project volume to timestamped tar.gz
make backup-enc         # Encrypted backup (AES-256, prompts for passphrase)
make backup-list        # List all backups (plain + encrypted)
make restore FILE=...   # Restore from a plain backup
make restore-enc FILE=... # Restore from an encrypted backup
make backup-clean       # Delete backups older than 30 days

# Volume Management
make volume-status      # Show volume status and detected orphans
make volume-adopt FROM=x # Adopt volumes from project 'x'
make volume-check       # Run pre-flight volume check manually

# Security Overrides
make DIND=true up       # Enable Docker-in-Docker (mounts Docker socket)
make DEBUG=true up      # Enable debugger support (SYS_PTRACE + unconfined seccomp)
make DIND=true DEBUG=true up  # Both
```

## Setup Options

When using the setup scripts directly (instead of `make`):

| Flag (bash) | Flag (PowerShell) | Effect |
|---|---|---|
| `--slim` | `-Slim` | Build Node + Go only (skip .NET, Rust) |
| `--with-solana` | `-WithSolana` | Include Solana/Anchor profile |
| `--with-mobile` | `-WithMobile` | Include Android SDK + Flutter + RN |
| `--with-gpu` | `-WithGpu` | Include NVIDIA CUDA runtime |
| `--all` | `-All` | Build everything |

```bash
./scripts/setup.sh --slim             # Lightweight build
./scripts/setup.sh --with-solana      # Include Solana
./scripts/setup.sh --all --with-gpu   # Everything + GPU
```

## Authentication

### Option A: API Key

Add to your `.env` file:

```
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

Then restart: `make down && make up`

### Option B: OAuth (interactive)

```bash
make login
```

OAuth tokens are persisted in the `claude-auth` volume — you only need to login once.

## Claude Code Configuration

Claude Code uses a hierarchical settings system. Docker Claude mounts a global `settings.json` into the container and supports per-project overrides.

### Settings Hierarchy (highest priority wins)

```
Per-project    /workspace/my-project/.claude/settings.json      (team, checked into git)
Per-project    /workspace/my-project/.claude/settings.local.json (personal, git-ignored)
Global         ~/.claude/settings.json                           (mounted from config/)
```

### Global Settings

Edit `config/claude-settings.json` on your host to change global defaults. This file is mounted read-only into the container and symlinked to `~/.claude/settings.json` at startup. Changes take effect on next container restart.

The default config sets:

- **Model** — defaults to Opus
- **Environment** — model mappings for Haiku/Sonnet/Opus, API timeout, telemetry disabled
- **Attribution** — header disabled

### Per-Project Settings

Inside the container, create project-level settings that override globals:

```bash
make shell
cd /workspace/my-project
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(npm test:*)",
      "Bash(npm run:*)"
    ]
  }
}
EOF
```

An example project settings file is at `config/claude-project-settings.example.json`.

### Personal Project Settings (git-ignored)

For personal tweaks within a project that shouldn't be shared with your team:

```bash
cat > .claude/settings.local.json << 'EOF'
{
  "preferences": {
    "thinking": "always"
  }
}
EOF
```

### Local Plugin Marketplace

You can mount a local Claude Code plugin marketplace from your host into the container.

**1. Set the path in `.env`:**

```
CLAUDE_MARKETPLACE_PATH=/Users/<YOUR_USERNAME>/path/to/your/marketplace
```

**2. Restart:**

```bash
make down && make up
```

**3. Register inside the container:**

```bash
make shell
claude plugin marketplace add /etc/claude-code/marketplace
```

The marketplace is mounted read-only at `/etc/claude-code/marketplace`. File changes on your host are reflected immediately inside the container — no restart needed for updated plugins, though you may need to re-register the marketplace in Claude Code when adding new ones.

If `CLAUDE_MARKETPLACE_PATH` is not set in `.env`, it falls back to the empty `./marketplace/` folder (no error).

## Port Mappings

All host ports use a **`${PORT_BASE}xxx`** pattern (default: `41xxx`) to avoid conflicts with common services (e.g., macOS AirPlay uses port 5000). Inside the container, apps still listen on their standard ports.

Change `PORT_BASE` in `.env` when running multiple instances (e.g., `42` for second instance → 42xxx ports).

| Service | Container Port | Host Port (PORT_BASE=41) | Access From Host |
|---|---|---|---|
| React / Express | 3000 | `${PORT_BASE}300` → 41300 | `localhost:41300` |
| ASP.NET HTTP | 5000 | `${PORT_BASE}500` → 41500 | `localhost:41500` |
| ASP.NET HTTPS | 5001 | `${PORT_BASE}501` → 41501 | `localhost:41501` |
| Vite | 5173 | `${PORT_BASE}517` → 41517 | `localhost:41517` |
| Go / Generic | 8080 | `${PORT_BASE}808` → 41808 | `localhost:41808` |
| Vue / Metro | 8081 | `${PORT_BASE}881` → 41881 | `localhost:41881` |
| Solana RPC | 8899 | `${PORT_BASE}889` → 41889 | `localhost:41889` |
| Solana WS | 8900 | `${PORT_BASE}890` → 41890 | `localhost:41890` |
| Expo | 19000 | `${PORT_BASE}900` → 41900 | `localhost:41900` |
| Expo DevTools | 19001 | `${PORT_BASE}901` → 41901 | `localhost:41901` |
| Android Emulator | 5554 | `${PORT_BASE}554` → 41554 | `localhost:41554` |
| Android ADB | 5555 | `${PORT_BASE}555` → 41555 | `localhost:41555` |
| noVNC (visual browser) | 6080 | `${PORT_BASE}608` → 41608 | `localhost:41608` |

## Working with Projects

Since volumes are fully virtualized (no host bind mount), you work with code inside the container:

```bash
# Enter the container
make shell

# Clone a project
cd /workspace
git clone git@github.com:your-org/your-project.git
cd your-project

# Install dependencies
npm install              # Node.js
dotnet restore           # .NET
go mod download          # Go
cargo build              # Rust

# Start Claude Code in your project
claude
```

### Getting Files In / Out

```bash
# Copy files into the container (use container name from 'docker ps')
docker cp ./my-file.txt $(docker ps -q -f name=docker-claude):/workspace/

# Or specify the full container name
docker cp ./my-file.txt docker-claude-docker-claude-1:/workspace/

# Copy files out
docker cp docker-claude-docker-claude-1:/workspace/output.txt ./

# Or use git (recommended)
make shell
cd /workspace/project && git push
```

## Optional Profiles

### Solana Development

```bash
make solana-up
make shell-solana

# Inside the container
solana-test-validator
cd /workspace/my-solana-project
anchor build && anchor deploy
```

### Mobile Development (Android + Flutter + React Native)

```bash
make mobile-up
make shell-mobile

# Flutter
flutter create my_app && cd my_app && flutter build apk

# React Native
npx react-native init MyApp && cd MyApp && npx react-native run-android
```

> **Note:** iOS builds require macOS + Xcode and cannot run in Docker. Use your Mac host for iOS builds.

## Custom Builds

Build with only the stacks you need:

```bash
# Only Node.js and Go
make build-slim

# Or with full control
docker compose build \
  --build-arg INCLUDE_NODE=true \
  --build-arg INCLUDE_DOTNET=false \
  --build-arg INCLUDE_GOLANG=true \
  --build-arg INCLUDE_RUST=false \
  docker-claude
```

## VS Code Dev Container

1. Install the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
2. Open this project folder in VS Code
3. `Ctrl+Shift+P` → "Dev Containers: Reopen in Container"
4. VS Code builds the image and connects with all extensions pre-configured (ESLint, Prettier, C# Dev Kit, Go, rust-analyzer, Flutter, Docker, GitLens, and more)

## GPU / CUDA Support

GPU support works on **Windows (WSL2)** and **Linux** only. macOS does not support NVIDIA GPUs in Docker.

### Linux

```bash
# 1. Install NVIDIA drivers
sudo apt-get install -y nvidia-driver-550

# 2. Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit

# 3. Configure and verify
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu24.04 nvidia-smi

# 4. Build with GPU
make GPU=true build
```

### Windows (WSL2)

1. Install latest NVIDIA GPU drivers for Windows
2. Docker Desktop → Settings → General → enable "Use the WSL 2 based engine"
3. Docker Desktop → Settings → Docker Engine → add:
   ```json
   { "runtimes": { "nvidia": { "path": "nvidia-container-runtime", "runtimeArgs": [] } } }
   ```
4. Build: `.\scripts\setup.ps1 -WithGpu`

## Cross-Platform: Mac ↔ Windows

| Concern | Mac | Windows |
|---|---|---|
| Setup | `make build && make up` | `.\scripts\setup.ps1` |
| Compose files | `docker-compose.yml` | `docker-compose.yml` + `docker-compose.windows.yml` |
| Docker socket | Automatic | Via WSL2 backend |
| SSH | Agent forwarding (`SSH_AUTH_SOCK`) | Keys mounted from `%USERPROFILE%\.ssh` |
| GPU | Not supported | WSL2 + NVIDIA Container Toolkit |
| Line endings | LF (automatic) | LF enforced via `.gitattributes` + setup script sanitization |

## Version Management

Switch runtime versions inside the container:

```bash
# Node.js
nvm install 22 && nvm use 22

# .NET — add a channel
curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 7.0

# Rust
rustup install nightly && rustup default nightly

# Go — install a different version
curl -fsSL "https://go.dev/dl/go1.22.0.linux-$(dpkg --print-architecture).tar.gz" \
  | sudo tar -C /usr/local -xzf -
```

## Backup & Restore

The project volume (`{project}_vol-projects`) lives inside Docker's virtual filesystem — not on your host. Backups export it to a timestamped `.tar.gz` file.

### Manual Backup

```bash
# Create a backup (saved to ./backups/)
make backup
# Output: ✓ Backup complete: backups/docker-claude-backup_20260330_143000.tar.gz (2.1G)

# List all backups with sizes
make backup-list
```

### Restore

```bash
# Restore from a specific backup (stops containers, asks for confirmation)
make restore FILE=backups/docker-claude-backup_20260330_143000.tar.gz
# Then restart
make up
```

### Cleanup Old Backups

```bash
# Delete backups older than 30 days
make backup-clean
```

### Automated Daily Backups (cron)

To run backups automatically on your Mac:

```bash
# Open crontab
crontab -e

# Add this line for daily backups at 2am
0 2 * * * cd /path/to/docker-claude && make backup 2>&1 >> backups/cron.log
```

> **Note:** Backups work even when containers are stopped — they spin up a temporary container to read the volume. The `backups/` directory is git-ignored by default.

### Encrypted Backups

For sensitive projects, use AES-256-CBC encrypted backups via openssl:

```bash
# Create encrypted backup (prompts for passphrase)
make backup-enc

# Restore from encrypted backup (prompts for passphrase)
make restore-enc FILE=backups/docker-claude-backup_20260330_143000.tar.gz.enc
```

No GPG setup needed — just remember your passphrase. Losing it means the backup is unrecoverable.

### Automated Daily Encrypted Backups (cron)

```bash
crontab -e

# Uses BACKUP_PASS env var to avoid interactive prompt
0 2 * * * cd /path/to/docker-claude && BACKUP_PASS="your-passphrase" make backup-enc 2>&1 >> backups/cron.log
```

## Security

This environment is security-hardened by default. See [SECURITY.md](SECURITY.md) for full details.

### Defaults

- **Docker socket NOT mounted** — prevents host compromise
- **Ports bound to 127.0.0.1** — not visible on your local network
- **Default seccomp profile** — dangerous syscalls blocked
- **No extra capabilities** — SYS_PTRACE disabled
- **No piped script execution** — all install scripts downloaded to disk first
- **All downloads over HTTPS** — from official sources only
- **Encrypted backups available** — AES-256-CBC via openssl

### Security Overrides

When you need features that reduce security:

```bash
make DIND=true up                 # Docker-in-Docker (mounts host Docker socket)
make DEBUG=true up                # Debugger support (SYS_PTRACE + unconfined seccomp)
make DIND=true DEBUG=true up      # Both
```

### Accepted Risks

These are known and accepted for development convenience:

- **API keys in env vars** — visible in `docker inspect`; `.env` is git-ignored
- **SSH agent forwarding** — container can use (but not extract) your SSH keys
- **Git config mounted** — read-only; exposes name/email

## Troubleshooting

### Port conflict on startup (e.g., "port 5000 already in use")

All host ports use the 41xxx range to avoid conflicts. If you still hit a conflict, check what's using the port: `lsof -i :41300` (Mac) or `netstat -ano | findstr 41300` (Windows). Edit the port mapping in `docker-compose.yml` if needed.

### "Permission denied" on entrypoint.sh

The setup scripts automatically sanitize file permissions and line endings. If you skipped the setup script, run manually:

```bash
chmod +x scripts/entrypoint.sh scripts/setup.sh
sed -i '' 's/\r$//' scripts/entrypoint.sh    # Mac
sed -i 's/\r$//' scripts/entrypoint.sh       # Linux
```

### "Permission denied" on Docker socket

```bash
# Inside the container
sudo chmod 666 /var/run/docker.sock
```

### NVM not found in non-interactive shells

```bash
export NVM_DIR="/usr/local/nvm" && . "$NVM_DIR/nvm.sh"
```

### Slow file I/O on Mac

Named volumes (which we use) are the fastest option on Docker Desktop for Mac. Ensure VirtioFS is enabled: Docker Desktop → Settings → General → "VirtioFS".

### Windows line ending issues

The setup script auto-converts CRLF → LF before building. If you still see issues:

```bash
git config --global core.autocrlf input
```

## Project Structure

```
docker-claude/
├── .devcontainer/
│   └── devcontainer.json          # VS Code Dev Container config
├── .dockerignore                  # Build context exclusions
├── .env.example                   # Template for environment variables
├── .gitignore                     # Git exclusions
├── Dockerfile                     # Core image (conditional runtimes)
├── Dockerfile.mobile              # Mobile profile (Android/Flutter/RN)
├── Dockerfile.solana              # Solana profile (Solana CLI/Anchor)
├── Makefile                       # All commands (run: make help)
├── README.md                      # This file
├── SECURITY.md                    # Security documentation
├── claude-settings.json           # Claude Code global settings (source for config/)
├── claude-project-settings.example.json  # Example per-project settings
├── config/
│   ├── .bashrc                    # Shell config (prompt, aliases, PATH)
│   ├── .gitattributes             # LF enforcement for cross-platform
│   ├── claude-settings.json       # Claude Code global settings (mounted into container)
│   ├── novnc-startup.sh           # noVNC startup script for visual browser
│   ├── starship.toml              # Starship prompt config (Catppuccin Powerline)
│   └── sudoers-dev                # Passwordless sudo config for dev user
├── docker-compose.debug.yml       # Debug override (SYS_PTRACE + seccomp)
├── docker-compose.dind.yml        # DinD override (Docker socket mount)
├── docker-compose.gpu.yml         # GPU override (NVIDIA device passthrough)
├── docker-compose.windows.yml     # Windows-specific overrides
├── docker-compose.yml             # Main compose (services, volumes, ports)
├── marketplace/                   # Default (empty) plugin marketplace fallback
│   └── .gitkeep                   # Keeps empty directory in git
├── plans/                         # Implementation plans and RFCs
│   └── browser-integration-plan.md
├── scripts/
│   ├── entrypoint.sh              # Container startup (runtime init, auth check)
│   ├── setup.ps1                  # One-command setup (Windows)
│   ├── setup.sh                   # One-command setup (Mac/Linux)
│   └── volume-check.sh            # Volume detection and migration script
└── .volume-state                  # Per-folder volume tracking (git-ignored)
```

## License

MIT License — see [LICENSE](LICENSE) for details.
