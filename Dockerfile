FROM node:20-alpine

# Install tools needed for setup
RUN apk add --no-cache curl git

# Install uv (provides `uv` and `uvx`) into ~/.local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Ensure uv is on PATH and quiet npm output a bit
ENV PATH="/root/.local/bin:${PATH}"
RUN npm config set fund false \
 && npm config set update-notifier false

# Install the correct mcp-proxy (sparfenyuk/mcp-proxy) via uv
# Use GitHub repo to ensure latest version as requested
RUN uv tool install git+https://github.com/sparfenyuk/mcp-proxy

WORKDIR /app
