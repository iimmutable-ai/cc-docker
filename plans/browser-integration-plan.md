# Implementation Plan: Built-in Browser for Docker Claude

## Overview

Add a secure browser to the docker-claude container for testing and debugging web apps, with both headless (Playwright) and visual (noVNC) modes.

## Goals

1. Enable automated browser testing from inside the container
2. Provide visual browser access via noVNC for manual testing/debugging
3. Integrate with Claude Code via MCP or CLI for browser automation

---

## Phase 1: Add Headless Browser (Playwright)

### Files Modified
- `Dockerfile`

### Steps

1. **Install Playwright and browsers**
   ```dockerfile
   # In Dockerfile, after Node.js section
   RUN if [ "${INCLUDE_NODE}" = "true" ]; then \
         . $NVM_DIR/nvm.sh \
         && npm install -g playwright \
         && npx playwright install --with-deps chromium firefox \
         && echo ">>> Playwright installed"; \
       fi
   ```

2. **Add dependency packages for headless browser**
   ```dockerfile
   # Add to apt-get install section:
   libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
   libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2 libpango-1.0-0 \
   libcairo2 libatspi2.0-0
   ```

---

## Phase 2: Add Visual Browser (noVNC)

### Files Modified
- `Dockerfile`

### Steps

1. **Install X server and VNC dependencies**
   ```dockerfile
   # Add to apt-get install:
   xvfb x11vnc websockify novnc firefox-esr chromium-browser
   ```

2. **Create noVNC startup script** (`config/novnc-startup.sh`)
   - Start Xvfb on display :1
   - Start Firefox/Chromium on :1
   - Start x11vnc on port 5900
   - Start websockify to bridge VNC to WebSocket

3. **Update Dockerfile to copy and configure noVNC**
   ```dockerfile
   COPY config/novnc-startup.sh /usr/local/bin/novnc-startup
   RUN chmod +x /usr/local/bin/novnc-startup
   ```

---

## Phase 3: Update docker-compose.yml

### Files Modified
- `docker-compose.yml`

### Steps

1. **Add noVNC port**
   ```yaml
   ports:
     - "127.0.0.1:41608:6080"   # noVNC web interface
   ```

2. **Add volume for persistent browser data (optional)**
   ```yaml
   volumes:
     - vol-browser:/home/${DEV_USER:-dev}/.browser-cache
   ```

---

## Phase 4: Add Makefile Commands

### Files Modified
- `Makefile`

### Steps

Add these targets:

```makefile
# Visual browser
.PHONY: browser
browser:
	@echo "Opening noVNC at http://localhost:41608"
	@xdg-open http://localhost:41608 2>/dev/null || open http://localhost:41608 2>/dev/null || echo "Open http://localhost:41608 in your browser"

# Headless browser test
.PHONY: browser-test
browser-test:
	docker compose exec docker-claude npx playwright test

# Stop browser service
.PHONY: browser-stop
browser-stop:
	docker compose exec docker-claude pkill -f "firefox|xvfb|x11vnc" || true

# Browser status
.PHONY: browser-status
browser-status:
	@echo "noVNC: http://localhost:41608"
	@echo "To start: docker compose exec -d docker-claude /usr/local/bin/novnc-startup"
```

---

## Phase 5: MCP Integration (Optional Enhancement)

### Files Modified
- `config/claude-settings.json` or marketplace plugins

### Steps

1. **Add Playwright MCP server** (if available) to enable Claude Code to control the browser
2. Or create custom script wrapper that Claude Code can invoke

---

## Verification

After implementation, test with:

```bash
# 1. Rebuild image
make build

# 2. Start container
make up

# 3. Test headless
make shell
npx playwright screenshot https://localhost:41300 --browser=chromium

# 4. Test visual
make shell
/usr/local/bin/novnc-startup &

# 5. Open browser on host
open http://localhost:41608
```

---

## Security Considerations

- Firefox/Chromium runs in container (sandboxed)
- noVNC served only on localhost (127.0.0.1)
- No persistent browser profile data by default
- Consider adding `--no-sandbox` flag for Chromium in container environment