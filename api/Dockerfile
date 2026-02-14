# --- Build stage ---
FROM node:22-bookworm-slim AS build
WORKDIR /app/api
COPY api/package.json api/package-lock.json ./
RUN npm ci
COPY api/ ./
RUN npm run build

# --- Production stage ---
FROM node:22-bookworm-slim

ARG GIT_SHA=unknown
ARG BUILD_TIMESTAMP=unknown
ENV GIT_SHA=${GIT_SHA}
ENV BUILD_TIMESTAMP=${BUILD_TIMESTAMP}

WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-venv \
    python3-pip \
    libeccodes0 \
    unzip \
    curl \
    gdal-bin \
    python3-gdal \
  && rm -rf /var/lib/apt/lists/*

# Install API dependencies (prod only)
WORKDIR /app/api
COPY api/package.json api/package-lock.json ./
RUN npm ci --omit=dev

# Copy built API artifacts
COPY --from=build /app/api/dist ./dist
COPY --from=build /app/api/public ./public

# Copy scripts (chart tile processing, etc.)
COPY api/scripts ./scripts

# HRRR processor (Python)
WORKDIR /app/hrrr-processor
COPY hrrr-processor/requirements.txt ./requirements.txt
RUN python3 -m venv /app/hrrr-processor/venv \
  && /app/hrrr-processor/venv/bin/pip install --no-cache-dir -r /app/hrrr-processor/requirements.txt
COPY hrrr-processor/process.py ./process.py

# Prefer the known-good venv python in container environments.
ENV HRRR_PYTHON_PATH=/app/hrrr-processor/venv/bin/python3

WORKDIR /app/api
EXPOSE 3001
CMD ["node", "dist/main.js"]
