**Overview**

- Dockerized MCP hub that exposes the hatago MCP server over SSE/Streamable HTTP via sparfenyuk/mcp-proxy.
- Single service (`mcp-hub`) defined in `compose.yml`.
- Container base: `node:20-alpine`. Installs `uv` and the official Python-based `mcp-proxy` from `sparfenyuk/mcp-proxy`.
- Proxy listens on port `3535` and loads a named stdio server from `mcp-proxy.config.json`.
- The named server runs `npx @himorishige/hatago-mcp-hub serve --stdio --config ./hatago.config.json`.

**Why This Repository**

- Goal: use `@himorishige/hatago-mcp-hub`. It supports both stdio and SSE modes.
- Dify compatibility: Dify’s MCP client expects an initial SSE event named `endpoint` immediately after connecting. That event carries the HTTP URL for subsequent JSON-RPC POSTs.
- Problem: even when `hatago-mcp-hub` is run in SSE mode, its SSE implementation does not emit this initial `event: endpoint`, so Dify fails right after connect with an initialization error.
- Solution: place `sparfenyuk/mcp-proxy` in front. The proxy exposes a compliant SSE endpoint (that includes the initial `endpoint` event) and spawns `hatago-mcp-hub` in stdio mode behind it, making the server consumable by Dify.

References: see discussions on Dify’s expected `event: endpoint` handshake for MCP SSE clients.

**Repository Layout**

- `Dockerfile`
  - Installs `curl` and `git`.
  - Installs `uv` and then `mcp-proxy` via `uv tool install git+https://github.com/sparfenyuk/mcp-proxy`.
  - Exposes `mcp-proxy` on `PATH`.
- `compose.yml`
  - Builds the image from the local `Dockerfile` and starts `mcp-proxy` on port `3535`.
  - Uses `--named-server-config /app/mcp-proxy.config.json`.
  - Mounts `./hatago.config.json` into the container.
- `mcp-proxy.config.json`
  - Named servers configuration for the proxy. Preconfigured to spawn `hatago-mcp-hub` in stdio mode using `npx`.
  - Typically you do NOT need to edit this; add/modify MCP servers in `hatago.config.json` instead.
- `hatago.config.json` (required, user-provided)
  - Placed at repository root and mounted into the container as `/app/hatago.config.json`.

**Prerequisites**

- Docker and Docker Compose v2.
- A valid `hatago.config.json` in the repository root.

**Quick Start**

- Place your `hatago.config.json` at the repository root.
- Build and run:
  - `docker compose build --no-cache`
  - `docker compose up`
- Endpoints (named server: `hatago`):
  - SSE: `http://localhost:3535/servers/hatago/sse`
  - Streamable HTTP: `http://localhost:3535/servers/hatago/mcp`

**Configuration**

- Users typically customize `hatago.config.json`. Below is an example that combines local stdio servers and remote SSE/HTTP servers:
```
{
  "$schema": "https://raw.githubusercontent.com/himorishige/hatago-mcp-hub/main/schemas/config.schema.json",
  "version": 1,
  "logLevel": "info",
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "some-remote-sse": {
      "url": "https://example.com/sse",
      "type": "sse"
    },
    "some-remote-http": {
      "url": "https://api.example.com/mcp",
      "type": "http",
      "headers": {
        "Authorization": "Bearer ${API_KEY}"
      }
    }
  }
}
```
- After editing `hatago.config.json`, restart the container or use `--watch` when running hatago locally to hot-reload.

**Ports and Volumes**

- Ports
  - `3535:3535` is published for the proxy.
  - `3500:3500` is currently mapped in `compose.yml` for potential future use; remove if unnecessary.
- Volumes (in `compose.yml`)
  - `./hatago.config.json:/app/hatago.config.json:ro` (required)
  - `./mcp-proxy.config.json:/app/mcp-proxy.config.json:ro` (required)
  - Additional mounts (e.g., Google Calendar tokens, `gcp-oauth.keys.json`) are examples for specific servers; remove if not needed.

**How It Works**

- The container starts `mcp-proxy` (from `sparfenyuk/mcp-proxy`) with `--named-server-config`.
- `mcp-proxy` exposes SSE/HTTP on port `3535` and spawns the `hatago` stdio server via the command from `mcp-proxy.config.json`.

**Customization**

- Change the port by editing `compose.yml` (`ports:` and the `--port` flag if needed).
- Pin a specific `mcp-proxy` version by switching the Dockerfile line to `uv tool install mcp-proxy` or using a git ref (e.g., `git+https://github.com/sparfenyuk/mcp-proxy@v0.3.2`).
- Remove unused volume mounts or extra port mappings from `compose.yml`.

**Troubleshooting**

- Container exits immediately
  - Ensure `hatago.config.json` exists and is valid.
  - Ensure `mcp-proxy.config.json` is valid JSON and references the correct relative path `./hatago.config.json`.
- Permission errors on mounted files
  - Verify the host files exist and your user has read permissions.
- Wrong proxy binary
  - This image installs the Python-based `sparfenyuk/mcp-proxy` via `uv`. If you previously installed an npm package named `mcp-proxy`, it is unrelated.
