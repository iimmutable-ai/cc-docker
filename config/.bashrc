# =============================================================================
# .bashrc — Claude Code Dev Environment
# =============================================================================

# -- Claude Code env cleanup --
[[ -z "$ANTHROPIC_BASE_URL" ]] && unset ANTHROPIC_BASE_URL

# -- NVM --
export NVM_DIR="/usr/local/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# -- Go --
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

# -- .NET (if installed) --
if [ -x "/usr/local/dotnet/dotnet" ]; then
    export DOTNET_ROOT=/usr/local/dotnet
    export PATH=$DOTNET_ROOT:$PATH
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export DOTNET_NOLOGO=1
fi

# -- Rust --
export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo
export PATH=$CARGO_HOME/bin:$PATH

# -- Solana (if installed) --
if [ -d "$HOME/.local/share/solana/install/active_release/bin" ]; then
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
fi

# -- Flutter (if installed) --
if [ -d "/opt/flutter/bin" ]; then
    export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"
fi

# -- Android (if installed) --
if [ -d "/opt/android-sdk" ]; then
    export ANDROID_HOME=/opt/android-sdk
    export ANDROID_SDK_ROOT=$ANDROID_HOME
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
fi

# -- SSH Agent --
if [ -S "/ssh-agent" ]; then
    export SSH_AUTH_SOCK=/ssh-agent
fi

# -- Starship Prompt --
if command -v starship &> /dev/null; then
    export STARSHIP_CONFIG=/home/dev/.config/starship.toml
    eval "$(starship init bash)"
fi

# -- Aliases --
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias y='yazi'
alias lg='lazygit'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -20'
alias gd='git diff'
alias dc='docker compose'
alias ws='cd /workspace'
alias claude-login='claude login'

# -- Browser (noVNC) --
alias browser-start='novnc-startup'
alias browser-stop='novnc-startup stop'

# -- Tab completion --
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# -- GitHub CLI completion --
if command -v gh &> /dev/null; then
    eval "$(gh completion -s bash)" 2>/dev/null
fi

# -- Auto-fix permissions before each prompt --
# This catches files copied via docker cp while shell is active
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_quick_fix_permissions"
_quick_fix_permissions() {
    # Quick check - only run full fix if there are non-dev owned files
    # Using -print -quit for efficiency (stops after first match)
    if sudo find /workspace -maxdepth 2 -not -user dev -print -quit 2>/dev/null | grep -q .; then
        sudo find /workspace -not -user dev 2>/dev/null | while IFS= read -r item; do
            [ -e "$item" ] && sudo chown -h dev:dev "$item" 2>/dev/null
        done
        sudo find /home/dev -not -user dev 2>/dev/null | while IFS= read -r item; do
            [ -e "$item" ] && sudo chown -h dev:dev "$item" 2>/dev/null
        done
        # Make everything readable (handles 600 permissions from macOS)
        sudo chmod -R a+rX /workspace /home/dev 2>/dev/null
    fi
}

# -- Initial fix on shell start (runs once) --
_quick_fix_permissions

# -- Workspace shortcut --
cd /workspace 2>/dev/null || true

# -- GitHub CLI credential helper auto-configure --
if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        # Auto-configure gh as git credential helper (picks up 'gh auth login' without restart)
        if [ -n "$GIT_CONFIG_GLOBAL" ] && [ -f "$GIT_CONFIG_GLOBAL" ]; then
            if ! git config -f "$GIT_CONFIG_GLOBAL" credential.helper 2>/dev/null | grep -q "gh auth git-credential"; then
                git config -f "$GIT_CONFIG_GLOBAL" credential.helper '!gh auth git-credential'
            fi
        fi
    else
        echo -e "${YELLOW}GitHub CLI not authenticated.${NC} Run ${BLUE}gh auth login${NC} to enable git push/pull over HTTPS."
    fi
fi
