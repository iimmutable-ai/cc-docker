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

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Docker Claude — Development Environment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# -- NVM --
export NVM_DIR="/usr/local/nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    echo -e "${GREEN}✓${NC} Node.js $(node --version 2>/dev/null || echo 'not loaded')"
fi

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

# -- Rust --
if [ -d "/usr/local/cargo" ]; then
    export PATH="/usr/local/cargo/bin:$PATH"
    echo -e "${GREEN}✓${NC} Rust $(rustc --version 2>/dev/null | awk '{print $2}' || echo 'installed')"
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

# -- Claude Code Auth --
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo -e "${GREEN}✓${NC} Claude Code: API key configured"
elif [ -f "/home/dev/.claude/credentials.json" ] || [ -f "/home/dev/.claude/.credentials.json" ]; then
    echo -e "${GREEN}✓${NC} Claude Code: OAuth session found"
else
    echo -e "${YELLOW}!${NC} Claude Code: No auth configured"
    echo -e "    Set ANTHROPIC_API_KEY or run: ${BLUE}claude login${NC}"
fi

# -- Claude Code Settings --
if [ -f "/etc/claude-code/settings.json" ]; then
    # Symlink mounted settings into Claude Code's expected location
    ln -sf /etc/claude-code/settings.json /home/dev/.claude/settings.json 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Claude Code: Global settings loaded"
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

    # Extract installed plugin names (keys of the JSON object)
    local plugin_names
    plugin_names=$(grep -oP '"([^"]+)"\s*:' "$installed_json" 2>/dev/null | grep -oP '"[^"]+"' | tr -d '"' | grep -v '^\s*$' || true)
    [ -n "$plugin_names" ] || return 0

    local fixed=0 ok=0
    for plugin_name in $plugin_names; do
        local plugin_dir="$plugins_dir/$plugin_name"
        # Create directory if it doesn't exist
        if [ ! -d "$plugin_dir" ]; then
            mkdir -p "$plugin_dir"
            echo -e "    Created plugin directory: ${plugin_name}"
        fi

        # Check if directory has actual files (not just empty)
        if [ -z "$(ls -A "$plugin_dir" 2>/dev/null)" ]; then
            # Directory exists but is empty — find the source in marketplace
            if [ -d "$marketplace/$plugin_name" ]; then
                cp -rn "$marketplace/$plugin_name/." "$plugin_dir/" 2>/dev/null && \
                    echo -e "    ${GREEN}✓${NC} Synced content: ${plugin_name}" || \
                    echo -e "    ${RED}✗${NC} Failed to sync: ${plugin_name}"
                fixed=$((fixed + 1))
            else
                # Plugin name might differ from marketplace directory — try all subdirs
                local found=0
                for src_dir in "$marketplace"/*/; do
                    local src_name
                    src_name=$(basename "$src_dir")
                    # Check if this marketplace dir looks like it matches (same name or contains matching plugin metadata)
                    if [ "$src_name" = "$plugin_name" ] || \
                       grep -ql "$plugin_name" "$src_dir"plugin.json 2>/dev/null; then
                        cp -rn "$src_dir." "$plugin_dir/" 2>/dev/null && \
                            echo -e "    ${GREEN}✓${NC} Synced content: ${plugin_name} (from ${src_name})" && \
                            found=1 && break
                    fi
                done
                if [ "$found" -eq 0 ]; then
                    echo -e "    ${RED}✗${NC} No source found in marketplace for: ${plugin_name}"
                else
                    fixed=$((fixed + 1))
                fi
            fi
        else
            ok=$((ok + 1))
        fi
    done

    # Print summary if any work was done
    if [ "$fixed" -gt 0 ]; then
        echo -e "    ${GREEN}→${NC} Synced ${fixed} plugin(s), ${ok} already OK"
    fi

    # Warn about any empty plugin directories
    for plugin_name in $plugin_names; do
        local plugin_dir="$plugins_dir/$plugin_name"
        if [ -d "$plugin_dir" ] && [ -z "$(ls -A "$plugin_dir" 2>/dev/null)" ]; then
            echo -e "    ${YELLOW}!${NC} Plugin still empty: ${plugin_name}"
            echo -e "      Run: ${BLUE}make reset-plugins && make down && make up${NC}"
        fi
    done
}

if [ -d "/etc/claude-code/marketplace" ] && [ "$(ls -A /etc/claude-code/marketplace 2>/dev/null | grep -v .gitkeep)" ]; then
    PLUGIN_COUNT=$(find /etc/claude-code/marketplace -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✓${NC} Claude Code: Local marketplace mounted (${PLUGIN_COUNT} plugin(s))"

    # Check installed plugins and their content status
    INSTALLED_JSON="/home/dev/.claude/plugins/installed_plugins.json"
    if [ -f "$INSTALLED_JSON" ]; then
        INSTALLED_COUNT=$(grep -oP '"([^"]+)"\s*:' "$INSTALLED_JSON" 2>/dev/null | grep -oP '"[^"]+"' | tr -d '"' | grep -v '^\s*$' | wc -l | tr -d ' ')
        echo -e "    ${INSTALLED_COUNT} plugin(s) installed"
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
