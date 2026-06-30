#!/bin/bash
# =============================================================================
# Container Entrypoint — Claude Code Dev Environment
# Handles: NVM init, SSH agent, Claude auth, Docker group, runtime checks
# =============================================================================

set -e

# -- Command-line flags --
if [ "$1" = "--sync-plugins" ]; then
    sync_plugin_content
    exit 0
fi

# -- Colors for output --
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

export BROWSER=echo  # Print URLs to terminal (no display server by default)

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Docker Claude — Development Environment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# -- Home Volume Initialization --
# On first start, the named volume is empty — seed it from image skeleton
if [ ! -f "/home/dev/.bashrc" ] && [ -f "/etc/skel-dev/.bashrc" ]; then
    cp -a /etc/skel-dev/. /home/dev/
    chown -R dev:dev /home/dev
    echo -e "${GREEN}✓${NC} Home volume initialized from image"
fi

# -- Migrate legacy vol-claude-auth (if detected) --
if [ ! -d "/home/dev/.claude" ] && [ -d "/mnt/migrate-auth/.claude" ]; then
    cp -a /mnt/migrate-auth/. /home/dev/
    chown -R dev:dev /home/dev
    echo -e "${GREEN}✓${NC} Migrated data from legacy vol-claude-auth"
fi

# -- Git Config Fix --
# Host .gitconfig may contain credential helpers (e.g. macOS gh CLI) that
# don't exist inside the container. Create a writable copy with ALL helpers removed.
if [ -f "/home/dev/.gitconfig" ]; then
    cp /home/dev/.gitconfig /home/dev/.gitconfig.container
    # Remove top-level credential helper
    git config -f /home/dev/.gitconfig.container --unset-all credential.helper 2>/dev/null || true
    # Remove URL-scoped credential helpers (e.g., credential.https://github.com.helper set by gh CLI)
    git config -f /home/dev/.gitconfig.container --get-regexp 'credential\..+\.helper' 2>/dev/null | \
        cut -d' ' -f1 | \
        while read -r key; do
            git config -f /home/dev/.gitconfig.container --unset-all "$key" 2>/dev/null || true
        done
    # Re-enable gh as credential helper if gh is authenticated inside the container
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        git config -f /home/dev/.gitconfig.container credential.helper '!gh auth git-credential'
    fi
    export GIT_CONFIG_GLOBAL="/home/dev/.gitconfig.container"
fi

# -- NVM --
export NVM_DIR="/usr/local/nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    echo -e "${GREEN}✓${NC} Node.js $(node --version 2>/dev/null || echo 'not loaded')"
fi

# -- User-local bin (native Claude Code, persists on vol-home) --
# Ensure the dir exists on volumes created before this change, then PATH it.
mkdir -p "${HOME}/.local/bin"
chown -R "${DEV_USER:-dev}:${DEV_USER:-dev}" "${HOME}/.local" 2>/dev/null || true

# Symlink baked native binary if no runtime install exists.
# - Fresh volume / post-reset: ~/.local/bin/claude absent → link to /opt/claude
# - Runtime claude install <ver>: writes its own ~/.local/bin/claude, left alone
# - make claude-reset removes the link → next start re-creates it (no rebuild)
if [ -x /opt/claude/bin/claude ] && [ ! -e "${HOME}/.local/bin/claude" ]; then
    ln -s /opt/claude/bin/claude "${HOME}/.local/bin/claude"
    chown -h "${DEV_USER:-dev}:${DEV_USER:-dev}" "${HOME}/.local/bin/claude" 2>/dev/null || true
fi

export PATH="${HOME}/.local/bin:${PATH}"

# -- .NET --
if [ -x "/usr/local/dotnet/dotnet" ]; then
    export PATH="/usr/local/dotnet:$PATH"
    echo -e "${GREEN}✓${NC} .NET $(/usr/local/dotnet/dotnet --version 2>/dev/null || echo 'installed')"
fi

# -- Go --
if [ -d "/usr/local/go" ]; then
    export PATH="/usr/local/go/bin:/home/dev/go/bin:$PATH"
    export GOPATH="/home/dev/go"
    mkdir -p "$GOPATH"
    echo -e "${GREEN}✓${NC} Go $(go version 2>/dev/null | awk '{print $3}' || echo 'installed')"
fi

mkdir -p /home/dev/.config/lazygit

# -- Rust --
if [ -d "/usr/local/cargo" ]; then
    export PATH="/usr/local/cargo/bin:$PATH"
    echo -e "${GREEN}✓${NC} Rust $(rustc --version 2>/dev/null | awk '{print $2}' || echo 'installed')"
fi

# -- Browser / Playwright --
PW_VERSION=$(npx playwright --version 2>/dev/null | awk '{print $3}')
if [ -n "$PW_VERSION" ]; then
    echo -e "${GREEN}✓${NC} Browser ${PW_VERSION}"
    echo -e "    Visual: ${BLUE}novnc-startup${NC} | Headless: ${BLUE}npx playwright <command>${NC}"
elif command -v novnc-startup &> /dev/null; then
    echo -e "${GREEN}✓${NC} Browser (noVNC available)"
else
    echo -e "${YELLOW}!${NC} Browser not installed (INCLUDE_BROWSER=false)"
fi

# -- Starship --
if command -v starship &> /dev/null; then
    echo -e "${GREEN}✓${NC} Starship prompt (Catppuccin Powerline)"
fi

# -- Yazi --
if command -v yazi &> /dev/null; then
    echo -e "${GREEN}✓${NC} Yazi $(yazi --version 2>/dev/null | head -1 | awk '{print $2}' || echo 'installed')"
fi

# -- Lazygit --
if command -v lazygit &> /dev/null; then
    echo -e "${GREEN}✓${NC} Lazygit $(lazygit --version 2>/dev/null || echo 'installed')"
fi

# -- GitHub CLI --
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
    if gh auth status &> /dev/null; then
        GH_USER=$(gh api user --jq .login 2>/dev/null)
        echo -e "${GREEN}✓${NC} GitHub CLI ${GH_VERSION} (authenticated: ${GH_USER})"
    else
        echo -e "${YELLOW}!${NC} GitHub CLI ${GH_VERSION} (not authenticated)"
        echo -e "    Run: ${BLUE}gh auth login${NC} to enable git push/pull over HTTPS"
    fi
fi

# -- Solana (if available) --
if [ -d "/home/dev/.local/share/solana/install/active_release" ]; then
    export PATH="/home/dev/.local/share/solana/install/active_release/bin:$PATH"
    echo -e "${GREEN}✓${NC} Solana $(solana --version 2>/dev/null | awk '{print $2}' || echo 'installed')"
fi

# -- Flutter (if available) --
if [ -d "/opt/flutter" ]; then
    export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"
    echo -e "${GREEN}✓${NC} Flutter $(flutter --version 2>/dev/null | head -1 | awk '{print $2}' || echo 'installed')"
fi

# -- SSH Agent Forwarding --
if [ -S "/ssh-agent" ]; then
    export SSH_AUTH_SOCK=/ssh-agent
    echo -e "${GREEN}✓${NC} SSH agent forwarded"
elif [ -d "/home/dev/.ssh" ] && [ "$(ls -A /home/dev/.ssh 2>/dev/null)" ]; then
    # Windows mode: keys mounted directly, start a local agent
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    for key in /home/dev/.ssh/id_*; do
        [ -f "$key" ] && [[ "$key" != *.pub ]] && ssh-add "$key" 2>/dev/null || true
    done
    echo -e "${GREEN}✓${NC} SSH keys loaded from mounted directory"
else
    echo -e "${YELLOW}!${NC} No SSH agent or keys detected"
fi

# -- Docker socket --
if [ -S "/var/run/docker.sock" ]; then
    echo -e "${GREEN}✓${NC} Docker socket available ($(docker --version 2>/dev/null | awk '{print $3}' | tr -d ','))"
else
    echo -e "${YELLOW}!${NC} Docker socket not mounted (default for security)"
    echo -e "    To enable DinD: ${BLUE}make DIND=true up${NC}"
fi

# -- Docker socket permissions --
# chmod unconditionally (runs as root, so -w test would always pass)
if [ -S "/var/run/docker.sock" ]; then
    chmod 666 /var/run/docker.sock 2>/dev/null
fi

# -- Claude Code Auth --
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo -e "${GREEN}✓${NC} Claude Code: API key configured"
elif [ -f "/home/dev/.claude/credentials.json" ] || [ -f "/home/dev/.claude/.credentials.json" ]; then
    echo -e "${GREEN}✓${NC} Claude Code: OAuth session found"
else
    echo -e "${YELLOW}!${NC} Claude Code: No auth configured"
    echo -e "    Set ANTHROPIC_API_KEY or run: ${BLUE}claude login${NC}"
fi

# -- Active Claude Code version (resolved after PATH is set) --
if command -v claude >/dev/null 2>&1; then
    CLAUDE_ACTIVE_VER="$(claude --version 2>/dev/null | head -n1 || echo unknown)"
    echo -e "${GREEN}✓${NC} Claude Code ${CLAUDE_ACTIVE_VER}"
    echo -e "\033[2m  (native; run 'claude update' to update, 'claude install <ver>' to pin)\033[0m"
fi

# -- Claude Code Settings --
SETTINGS_SRC="/etc/claude-code/settings.json"
SETTINGS_DEST="/home/dev/.claude/settings.json"

# Remove symlink if it exists (it points to read-only mount, prevents plugin installs)
if [ -L "$SETTINGS_DEST" ]; then
    rm "$SETTINGS_DEST"
    echo -e "${YELLOW}!${NC} Removed settings symlink (read-only mount)"
fi

if [ -f "$SETTINGS_SRC" ]; then
    # Copy only if settings doesn't exist (preserves container modifications)
    if [ ! -f "$SETTINGS_DEST" ]; then
        cp "$SETTINGS_SRC" "$SETTINGS_DEST"
        echo -e "${GREEN}✓${NC} Claude Code: Settings initialized from host"
    else
        echo -e "${GREEN}✓${NC} Claude Code: Settings present (preserved from volume)"
    fi
else
    echo -e "${YELLOW}!${NC} Claude Code: No global settings (using defaults)"
fi

# -- Claude Code Marketplace --
sync_plugin_content() {
    local marketplace="/etc/claude-code/marketplace"
    local plugins_dir="/home/dev/.claude/plugins"
    local installed_json="$plugins_dir/installed_plugins.json"

    # Need marketplace mounted and installed plugins metadata
    [ -d "$marketplace" ] || return 0
    [ -f "$installed_json" ] || return 0

    local fixed=0 ok=0 skipped=0
    # Process each installed plugin using jq to extract name and installPath
    while IFS= read -r plugin_entry; do
        local plugin_name=$(echo "$plugin_entry" | jq -r '.name')
        local install_path=$(echo "$plugin_entry" | jq -r '.installPath')

        # Skip if installPath is empty
        [ -n "$install_path" ] || continue

        # Check if content already exists at installPath
        if [ -d "$install_path" ] && [ -n "$(ls -A "$install_path" 2>/dev/null)" ]; then
            ok=$((ok + 1))
            continue
        fi

        # Only sync from local marketplace if installPath suggests local marketplace origin
        # Remote marketplace plugins (GitHub, etc.) are downloaded during install
        if [[ "$install_path" == *"/etc/claude-code/marketplace"* ]] || [[ "$install_path" == "$plugins_dir/$plugin_name"* ]]; then
            # Try to find source in marketplace and sync
            local found=0
            shopt -s nullglob
            for src_dir in "$marketplace"/*/ "$marketplace/plugins"/*/; do
                shopt -u nullglob
                [ -d "$src_dir" ] || continue
                local src_name=$(basename "$src_dir")
                # Match by name or plugin.json
                if [ "$src_name" = "$plugin_name" ] || \
                   grep -ql "$plugin_name" "$src_dir/plugin.json" 2>/dev/null; then
                    mkdir -p "$install_path"
                    cp -rn "$src_dir." "$install_path/" 2>/dev/null && \
                        echo -e "    ${GREEN}✓${NC} Synced content: ${plugin_name}" && \
                        found=1 && fixed=$((fixed + 1)) && break
                fi
                shopt -s nullglob
            done
            shopt -u nullglob
            if [ "$found" -eq 0 ]; then
                echo -e "    ${YELLOW}!${NC} No source in local marketplace for: ${plugin_name}"
                skipped=$((skipped + 1))
            fi
        else
            # Plugin from remote marketplace - should have been downloaded during install
            skipped=$((skipped + 1))
            echo -e "    ${YELLOW}!${NC} Plugin from remote marketplace: ${plugin_name} (not synced from local)"
        fi
    done < <(jq -c '.plugins | to_entries[] | {name: .key, installPath: .value[0].installPath}' "$installed_json" 2>/dev/null)

    # Print summary
    if [ "$ok" -gt 0 ]; then
        echo -e "    ${GREEN}→${NC} ${ok} already OK"
    fi
    if [ "$fixed" -gt 0 ]; then
        echo -e "    ${GREEN}→${NC} Synced ${fixed} from marketplace"
    fi
    if [ "$skipped" -gt 0 ]; then
        echo -e "    ${BLUE}→${NC} ${skipped} from remote marketplaces"
    fi
}

if [ -d "/etc/claude-code/marketplace" ] && [ "$(ls -A /etc/claude-code/marketplace 2>/dev/null | grep -v .gitkeep)" ]; then
    PLUGIN_COUNT=$(find /etc/claude-code/marketplace -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} Claude Code: Local marketplace mounted (${PLUGIN_COUNT} plugin(s))"

    # Check installed plugins and their content status
    INSTALLED_JSON="/home/dev/.claude/plugins/installed_plugins.json"
    if [ -f "$INSTALLED_JSON" ]; then
        INSTALLED_COUNT=$(jq -r '.plugins | keys | length' "$INSTALLED_JSON" 2>/dev/null || echo 0)
        [ "$INSTALLED_COUNT" -gt 0 ] && echo -e "    ${INSTALLED_COUNT} plugin(s) installed"
        sync_plugin_content
    else
        echo -e "    Register with: ${BLUE}claude plugin marketplace add /etc/claude-code/marketplace${NC}"
    fi
else
    echo -e "${YELLOW}!${NC} Claude Code: No local marketplace mounted"
fi

# -- Workspace --
echo ""
if [ "$(ls -A /workspace 2>/dev/null)" ]; then
    PROJECT_COUNT=$(find /workspace -maxdepth 1 -mindepth 1 -type d | wc -l)
    echo -e "${GREEN}✓${NC} Workspace: ${PROJECT_COUNT} project(s) in /workspace"
else
    echo -e "${YELLOW}!${NC} Workspace is empty. Get started:"
    echo -e "    ${BLUE}cd /workspace && git clone <your-repo>${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# -- Execute command --
exec "$@"
