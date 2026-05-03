# =============================================================================
# Makefile — Docker Claude Dev Environment
# Run 'make help' to see all available commands
# =============================================================================

.PHONY: help init build build-slim build-all up down restart shell claude login \
        solana-up mobile-up host-bind-up host-bind-mobile-up host-bind-solana-up \
        status logs clean nuke health \
        backup restore backup-list backup-clean backup-enc restore-enc \
        install-plugins reset-plugins sync-plugins \
        browser browser-start browser-stop browser-test browser-screenshot \
        volume-check volume-status volume-adopt

# =============================================================================
# Environment Setup
# =============================================================================

# Load environment variables from .env
-include .env

# Project name for container/volume naming (from .env or default)
# Use $(or ...) for default value in Make
PROJECT_NAME := $(or $(COMPOSE_PROJECT_NAME),cc-docker)
PORT_BASE_VAL := $(or $(PORT_BASE),41)

# Export variables for shell commands in recipes
export COMPOSE_PROJECT_NAME
export PORT_BASE
export PROJECT_NAME
export PORT_BASE_VAL

# Ensure .env exists before running most commands
.env:
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
		echo "Edit .env to customize COMPOSE_PROJECT_NAME and PORT_BASE for multi-instance setup."; \
	fi

init: .env ## Initialize environment (copy .env.example to .env if missing)
	@echo "Environment configured:"
	@echo "  COMPOSE_PROJECT_NAME: $(PROJECT_NAME)"
	@echo "  PORT_BASE: $(PORT_BASE_VAL)"
	@echo ""
	@echo "For multi-instance setup, edit .env to change these values."

# Detect OS for compose file selection
ifeq ($(OS),Windows_NT)
    COMPOSE_FILES := -f docker-compose.yml -f docker-compose.windows.yml
else
    COMPOSE_FILES := -f docker-compose.yml
endif

# GPU override (use: make GPU=true build)
GPU ?= false
ifeq ($(GPU),true)
    COMPOSE_FILES += -f docker-compose.gpu.yml
endif

# DinD override (use: make DIND=true up)
# ⚠️  Mounts Docker socket — gives container full host Docker access
DIND ?= false
ifeq ($(DIND),true)
    COMPOSE_FILES += -f docker-compose.dind.yml
endif

# Debug override (use: make DEBUG=true up)
# Adds SYS_PTRACE + unconfined seccomp for debuggers
DEBUG ?= false
ifeq ($(DEBUG),true)
    COMPOSE_FILES += -f docker-compose.debug.yml
endif

# Detect docker compose (plugin) vs standalone docker-compose
COMPOSE_CMD := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Docker Compose command with project name
COMPOSE := $(COMPOSE_CMD) $(COMPOSE_FILES)

# Container name (Docker Compose format: project-service-1)
CONTAINER := $(PROJECT_NAME)-cc-docker-1

# =============================================================================
# Help
# =============================================================================

help: .env ## Show this help
	@echo ""
	@echo "Docker Claude Dev Environment"
	@echo "============================="
	@echo "Project: $(PROJECT_NAME)"
	@echo ""
	@awk 'match($$0, /^[a-zA-Z_-]+:.*## /) { print }' Makefile | sort | \
		sed 's/:.*## /:##/' | awk -F':##' '{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make init              Initialize .env from .env.example"
	@echo "  make build             Build core image (all stacks)"
	@echo "  make build-slim        Build with Node + Go only"
	@echo "  make up                Start core environment"
	@echo "  make DIND=true up      Start with Docker-in-Docker enabled"
	@echo "  make DEBUG=true up     Start with debugger support (SYS_PTRACE)"
	@echo "  make solana-up         Start with Solana profile"
	@echo "  make mobile-up         Start with Mobile profile (Android)"
	@echo "  make host-bind-mobile-up  Start with host bind mount (iOS dev)"
	@echo "  make claude            Launch Claude Code CLI"
	@echo "  make GPU=true build    Build with NVIDIA GPU support"
	@echo "  make backup            Backup project volume"
	@echo "  make backup-enc        Encrypted backup (openssl)"
	@echo ""
	@echo "Multi-Instance Setup:"
	@echo "  1. Copy project to new directory"
	@echo "  2. Edit .env: COMPOSE_PROJECT_NAME=trial-claude PORT_BASE=42"
	@echo "  3. Run 'make up' — isolated containers/volumes/ports"
	@echo ""
	@echo "iOS Development (macOS only):"
	@echo "  make host-bind-mobile-up  Container edits + host Xcode/Simulator"
	@echo "  Then: cd ./workspace/my_app && flutter run -d iPhone"
	@echo ""

# =============================================================================
# Build
# =============================================================================

build: .env ## Build core image (all stacks)
	$(COMPOSE) build \
		--build-arg INCLUDE_NODE=true \
		--build-arg INCLUDE_DOTNET=true \
		--build-arg INCLUDE_GOLANG=true \
		--build-arg INCLUDE_RUST=true \
		--build-arg INCLUDE_BROWSER=true \
		--build-arg INCLUDE_GPU=$(GPU) \
		cc-docker

build-slim: .env ## Build slim image (Node + Go only)
	$(COMPOSE) build \
		--build-arg INCLUDE_NODE=true \
		--build-arg INCLUDE_DOTNET=false \
		--build-arg INCLUDE_GOLANG=true \
		--build-arg INCLUDE_RUST=false \
		--build-arg INCLUDE_BROWSER=false \
		--build-arg INCLUDE_GPU=false \
		cc-docker

build-all: build ## Build all images including profiles
	$(COMPOSE) --profile solana build cc-docker-solana
	$(COMPOSE) --profile mobile build cc-docker-mobile

build-no-cache: .env ## Build core image without cache
	$(COMPOSE) build --no-cache cc-docker

# =============================================================================
# Run
# =============================================================================

up: .env volume-check ## Start core environment (with volume check)
	$(COMPOSE) up -d
	@./scripts/volume-check.sh --create-manifest

down: ## Stop all services (volumes persist)
	$(COMPOSE) --profile solana --profile mobile down

restart: down up ## Restart all services

solana-up: .env ## Start with Solana profile
	$(COMPOSE) --profile solana up -d

mobile-up: .env ## Start with Mobile profile
	$(COMPOSE) --profile mobile up -d

# =============================================================================
# Host Bind Mount (iOS Development)
# =============================================================================
# Uses docker-compose.host-bind.yml to mount ./workspace from host
# Enables iOS development: container edits + host Xcode/Simulator builds

host-bind-up: .env ## Start with host workspace bind mount (core only)
	@if [ ! -d "${HOST_WORKSPACE_PATH:-./workspace}" ]; then \
		echo "Creating workspace directory: ${HOST_WORKSPACE_PATH:-./workspace}"; \
		mkdir -p "${HOST_WORKSPACE_PATH:-./workspace}"; \
	fi
	$(COMPOSE_CMD) $(COMPOSE_FILES) -f docker-compose.host-bind.yml up -d

host-bind-mobile-up: .env ## Start with host bind + Mobile profile (for iOS dev)
	@if [ ! -d "${HOST_WORKSPACE_PATH:-./workspace}" ]; then \
		echo "Creating workspace directory: ${HOST_WORKSPACE_PATH:-./workspace}"; \
		mkdir -p "${HOST_WORKSPACE_PATH:-./workspace}"; \
	fi
	$(COMPOSE_CMD) $(COMPOSE_FILES) -f docker-compose.host-bind.yml --profile mobile up -d

host-bind-solana-up: .env ## Start with host bind + Solana profile
	@if [ ! -d "${HOST_WORKSPACE_PATH:-./workspace}" ]; then \
		echo "Creating workspace directory: ${HOST_WORKSPACE_PATH:-./workspace}"; \
		mkdir -p "${HOST_WORKSPACE_PATH:-./workspace}"; \
	fi
	$(COMPOSE_CMD) $(COMPOSE_FILES) -f docker-compose.host-bind.yml --profile solana up -d

all-up: .env ## Start everything
	$(COMPOSE) --profile solana --profile mobile up -d

# =============================================================================
# Interactive
# =============================================================================

shell: .env ## Open bash shell in cc-docker
	$(COMPOSE) exec -u dev cc-docker bash

claude: .env ## Launch Claude Code CLI
	$(COMPOSE) exec cc-docker bash -c '. /usr/local/nvm/nvm.sh && claude'

login: .env ## Run Claude OAuth login
	$(COMPOSE) exec cc-docker bash -c '. /usr/local/nvm/nvm.sh && claude login'

install-plugins: .env ## Register marketplace and sync plugin content
	$(COMPOSE) exec cc-docker bash -c '. /usr/local/nvm/nvm.sh && claude plugin marketplace add /etc/claude-code/marketplace 2>/dev/null; claude plugin sync 2>/dev/null || /entrypoint.sh --sync-plugins; claude plugin list'

sync-plugins: .env ## Manually trigger plugin content sync from marketplace
	$(COMPOSE) exec cc-docker bash -c 'source /entrypoint.sh; sync_plugin_content'

reset-plugins: .env ## Clear stale plugin state for re-sync on next start
	$(COMPOSE) exec cc-docker bash -c 'rm -rf ~/.claude/plugins/agentic-* ~/.claude/plugins/superpowers 2>/dev/null; echo "Plugin state cleared. Restart to re-sync: make down && make up"'

# =============================================================================
# Browser (noVNC + Playwright)
# =============================================================================

browser: .env ## Open noVNC visual browser in host browser
	@echo "Opening noVNC at http://localhost:${PORT_BASE:-41}608/vnc.html"
	@open http://localhost:${PORT_BASE:-41}608/vnc.html 2>/dev/null || \
		xdg-open http://localhost:${PORT_BASE:-41}608/vnc.html 2>/dev/null || \
		echo "Open manually: http://localhost:${PORT_BASE:-41}608/vnc.html"

browser-start: .env ## Start noVNC visual browser inside container
	$(COMPOSE) exec -d cc-docker bash -c 'novnc-startup 2>&1 | tee /tmp/novnc.log'

browser-stop: .env ## Stop visual browser processes
	$(COMPOSE) exec cc-docker novnc-startup stop

browser-test: .env ## Run Playwright tests (usage: make browser-test TEST=path/to/test)
	$(COMPOSE) exec cc-docker bash -c '. /usr/local/nvm/nvm.sh && npx playwright test $(TEST)'

browser-screenshot: .env ## Take a Playwright screenshot (usage: make browser-screenshot URL=https://example.com)
	$(COMPOSE) exec cc-docker bash -c '. /usr/local/nvm/nvm.sh && npx playwright screenshot --browser=chromium $(URL) /tmp/screenshot.png && echo "Screenshot saved to /tmp/screenshot.png"'

shell-solana: .env ## Open shell in Solana container
	$(COMPOSE) --profile solana exec -u dev cc-docker-solana bash

shell-mobile: .env ## Open shell in Mobile container
	$(COMPOSE) --profile mobile exec -u dev cc-docker-mobile bash

# =============================================================================
# Status & Logs
# =============================================================================

status: .env ## Show running containers and volumes
	@echo "=== Containers (${COMPOSE_PROJECT_NAME:-cc-docker}) ==="
	@docker ps --filter "name=${COMPOSE_PROJECT_NAME:-cc-docker}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== Volumes ==="
	@docker volume ls --filter "name=${COMPOSE_PROJECT_NAME:-cc-docker}"
	@echo ""
	@echo "=== Image Sizes ==="
	@docker images --filter "reference=${COMPOSE_PROJECT_NAME:-cc-docker}*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

logs: .env ## Follow logs for cc-docker
	$(COMPOSE) logs -f cc-docker

logs-all: .env ## Follow logs for all services
	$(COMPOSE) --profile solana --profile mobile logs -f

# =============================================================================
# Health & Diagnostics
# =============================================================================

health: .env ## Run health check on all installed runtimes
	$(COMPOSE) exec cc-docker bash /workspace/.health-check.sh 2>/dev/null || \
	$(COMPOSE) exec cc-docker bash -c '\
		echo "=== Runtime Health Check ===" && \
		echo "" && \
		. /usr/local/nvm/nvm.sh 2>/dev/null && \
		echo -n "Node.js:  " && (node --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "npm:      " && (npm --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "pnpm:     " && (pnpm --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "yarn:     " && (yarn --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "tsc:      " && (tsc --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n ".NET:     " && (dotnet --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Go:       " && (go version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Rust:     " && (rustc --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Cargo:    " && (cargo --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Docker:   " && (docker --version 2>/dev/null || echo "NOT AVAILABLE") && \
		echo -n "Git:      " && (git --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Claude:   " && (claude --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Browser:  " && (. /usr/local/nvm/nvm.sh 2>/dev/null && npx playwright --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Solana:   " && (solana --version 2>/dev/null || echo "NOT INSTALLED") && \
		echo -n "Flutter:  " && (flutter --version 2>/dev/null | head -1 || echo "NOT INSTALLED") && \
		echo "" && \
		echo "=== Auth Status ===" && \
		if [ -n "$$ANTHROPIC_API_KEY" ]; then echo "API Key: configured"; \
		elif [ -f ~/.claude/credentials.json ] || [ -f ~/.claude/.credentials.json ]; then echo "OAuth: session found"; \
		else echo "Auth: NOT CONFIGURED — run claude login"; fi && \
		echo "" && \
		echo "=== Docker Socket ===" && \
		if [ -S /var/run/docker.sock ]; then echo "Socket: available"; else echo "Socket: NOT MOUNTED"; fi && \
		echo "" && \
		echo "=== Workspace ===" && \
		echo "Projects: $$(find /workspace -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)" && \
		echo "Disk usage: $$(du -sh /workspace 2>/dev/null | cut -f1)" \
	'

# =============================================================================
# Cleanup
# =============================================================================

clean: .env ## Stop containers and remove images (volumes persist)
	$(COMPOSE) --profile solana --profile mobile down --rmi local

nuke: .env ## ⚠️  Remove EVERYTHING (containers, volumes, images)
	@echo "⚠️  This will delete ALL containers, volumes, and images for project: ${COMPOSE_PROJECT_NAME:-cc-docker}"
	@echo "   Your project code in the volume will be PERMANENTLY LOST."
	@read -p "   Type 'yes' to confirm: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		$(COMPOSE) --profile solana --profile mobile down -v --rmi local; \
		echo "Done. Everything removed."; \
	else \
		echo "Cancelled."; \
	fi

# =============================================================================
# Backup & Restore
# =============================================================================
# Volume names are prefixed by COMPOSE_PROJECT_NAME (e.g., cc-docker_vol-projects)

BACKUP_DIR ?= ./backups

backup: .env ## Backup project volume to a timestamped tar.gz
	@mkdir -p $(BACKUP_DIR)
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S) && \
	VOLUME_NAME="${COMPOSE_PROJECT_NAME:-cc-docker}_vol-projects" && \
	BACKUP_FILE="$(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_$${TIMESTAMP}.tar.gz" && \
	echo "Backing up volume $$VOLUME_NAME → $${BACKUP_FILE} ..." && \
	docker run --rm \
		-v $$VOLUME_NAME:/workspace:ro \
		-v $$(cd $(BACKUP_DIR) && pwd):/backup \
		ubuntu:24.04 \
		tar czf /backup/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_$${TIMESTAMP}.tar.gz -C /workspace . && \
	SIZE=$$(du -h "$${BACKUP_FILE}" | cut -f1) && \
	echo "✓ Backup complete: $${BACKUP_FILE} ($${SIZE})"

restore: .env ## Restore project volume from a backup (usage: make restore FILE=backups/xxx.tar.gz)
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make restore FILE=backups/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_YYYYMMDD_HHMMSS.tar.gz"; \
		echo ""; \
		echo "Available backups:"; \
		ls -lh $(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*.tar.gz 2>/dev/null || echo "  No backups found in $(BACKUP_DIR)/"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "✗ File not found: $(FILE)"; \
		exit 1; \
	fi
	@VOLUME_NAME="${COMPOSE_PROJECT_NAME:-cc-docker}_vol-projects" && \
	echo "⚠️  This will REPLACE all contents of volume $$VOLUME_NAME with the backup." && \
	echo "   Backup file: $(FILE)" && \
	@read -p "   Type 'yes' to confirm: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		echo "Stopping containers..." && \
		$(COMPOSE) --profile solana --profile mobile down && \
		echo "Restoring to volume $$VOLUME_NAME from $(FILE) ..." && \
		docker run --rm \
			-v $$VOLUME_NAME:/workspace \
			-v $$(cd $$(dirname $(FILE)) && pwd):/backup:ro \
			ubuntu:24.04 \
			sh -c "rm -rf /workspace/* /workspace/.[!.]* 2>/dev/null; tar xzf /backup/$$(basename $(FILE)) -C /workspace" && \
		echo "✓ Restore complete. Run 'make up' to start." ; \
	else \
		echo "Cancelled."; \
	fi

backup-list: .env ## List all available backups for current project
	@echo "=== Backups in $(BACKUP_DIR)/ for ${COMPOSE_PROJECT_NAME:-cc-docker} ==="
	@ls -lh $(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*.tar.gz $(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*.tar.gz.enc 2>/dev/null \
		| awk '{printf "  %s  %s  %s\n", $$9, $$5, $$6" "$$7" "$$8}' \
		|| echo "  No backups found for this project."
	@echo ""
	@TOTAL=$$(ls $(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*.tar.gz $(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*.tar.gz.enc 2>/dev/null | wc -l | tr -d ' ') && \
	echo "Total: $${TOTAL} backup(s) for ${COMPOSE_PROJECT_NAME:-cc-docker}"
	@du -sh $(BACKUP_DIR) 2>/dev/null | awk '{printf "  Disk usage: %s\n", $$1}' || true

backup-clean: .env ## Delete backups older than 30 days for current project
	@echo "Removing backups older than 30 days from $(BACKUP_DIR)/ for ${COMPOSE_PROJECT_NAME:-cc-docker} ..."
	@find $(BACKUP_DIR) -name "${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*" -mtime +30 -print -delete 2>/dev/null \
		|| echo "  No old backups found."
	@echo "Done."

# =============================================================================
# Encrypted Backup & Restore (openssl)
# =============================================================================

backup-enc: .env ## Encrypted backup (openssl AES-256, prompts for passphrase)
	@mkdir -p $(BACKUP_DIR)
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S) && \
	VOLUME_NAME="${COMPOSE_PROJECT_NAME:-cc-docker}_vol-projects" && \
	BACKUP_FILE="$(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_$${TIMESTAMP}.tar.gz.enc" && \
	echo "Creating encrypted backup of volume $$VOLUME_NAME → $${BACKUP_FILE} ..." && \
	echo "You will be prompted for an encryption passphrase." && \
	docker run --rm \
		-v $$VOLUME_NAME:/workspace:ro \
		ubuntu:24.04 \
		tar czf - -C /workspace . \
	| openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -out "$${BACKUP_FILE}" && \
	SIZE=$$(du -h "$${BACKUP_FILE}" | cut -f1) && \
	echo "✓ Encrypted backup complete: $${BACKUP_FILE} ($${SIZE})" && \
	echo "  ⚠️  Store your passphrase safely — it cannot be recovered."

restore-enc: .env ## Restore from encrypted backup (usage: make restore-enc FILE=backups/xxx.tar.gz.enc)
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make restore-enc FILE=backups/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_YYYYMMDD_HHMMSS.tar.gz.enc"; \
		echo ""; \
		echo "Available encrypted backups:"; \
		ls -lh $(BACKUP_DIR)/${COMPOSE_PROJECT_NAME:-cc-docker}-backup_*.tar.gz.enc 2>/dev/null || echo "  No encrypted backups found in $(BACKUP_DIR)/"; \
		exit 1; \
	fi
	@if [ ! -f "$(FILE)" ]; then \
		echo "✗ File not found: $(FILE)"; \
		exit 1; \
	fi
	@VOLUME_NAME="${COMPOSE_PROJECT_NAME:-cc-docker}_vol-projects" && \
	echo "⚠️  This will REPLACE all contents of volume $$VOLUME_NAME with the backup." && \
	echo "   Backup file: $(FILE)" && \
	@read -p "   Type 'yes' to confirm: " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		echo "Stopping containers..." && \
		$(COMPOSE) --profile solana --profile mobile down && \
		echo "Decrypting and restoring to volume $$VOLUME_NAME from $(FILE) ..." && \
		openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$(FILE)" \
		| docker run --rm -i \
			-v $$VOLUME_NAME:/workspace \
			ubuntu:24.04 \
			sh -c "rm -rf /workspace/* /workspace/.[!.]* 2>/dev/null; tar xzf - -C /workspace" && \
		echo "✓ Restore complete. Run 'make up' to start." ; \
	else \
		echo "Cancelled."; \
	fi

# =============================================================================
# Volume Management (Multi-Instance Support)
# =============================================================================
# Handles volume name changes when COMPOSE_PROJECT_NAME is modified

volume-check: .env ## Pre-flight volume check before starting
	@./scripts/volume-check.sh --check

volume-status: .env ## Show volume status and detected orphans
	@./scripts/volume-check.sh --status

volume-adopt: .env ## Adopt orphan volumes (usage: make volume-adopt FROM=project-name)
	@if [ -z "$(FROM)" ]; then \
		echo "Usage: make volume-adopt FROM=<project-name>"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make volume-adopt FROM=cc-docker"; \
		echo "  make volume-adopt FROM=trial-claude"; \
		echo ""; \
		echo "Run 'make volume-status' to see available orphan volumes."; \
		exit 1; \
	fi
	@./scripts/volume-check.sh --adopt-from $(FROM)

