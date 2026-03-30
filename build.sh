#!/usr/bin/env bash
set -e

CONTAINER="dockge"
BUILD_DIR="/tmp/radarr-build"
IMAGE="radarr-local:latest"

echo "==> Syncing source to $CONTAINER..."
incus exec "$CONTAINER" -- rm -rf "$BUILD_DIR"
incus exec "$CONTAINER" -- mkdir -p "$BUILD_DIR"

tar -C /home/matt/radarr-fork -cf - \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='_output' \
    package.json yarn.lock tsconfig.json frontend Dockerfile \
  | incus exec "$CONTAINER" -- tar -xf - -C "$BUILD_DIR"

echo "==> Running lint (auto-fix)..."
incus exec "$CONTAINER" -- docker run --rm \
  -v "$BUILD_DIR":/build \
  node:20-alpine \
  sh -c "cd /build && yarn install --frozen-lockfile --silent 2>/dev/null && yarn lint --fix && yarn lint 2>&1"

echo "==> Syncing lint fixes back to host..."
incus exec "$CONTAINER" -- tar -C "$BUILD_DIR" -cf - \
    frontend/src \
  | tar -xf - -C /home/matt/radarr-fork

echo "==> Building image..."
incus exec "$CONTAINER" -- docker build -t "$IMAGE" "$BUILD_DIR"

echo "==> Restarting Radarr..."
incus exec "$CONTAINER" -- docker compose -f /opt/stacks/radarr/compose.yaml up -d --force-recreate

echo "==> Cleaning up..."
incus exec "$CONTAINER" -- rm -rf "$BUILD_DIR"

echo "==> Done. Radarr is running with your latest changes."
