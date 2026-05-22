#!/usr/bin/env bash
# scripts/deploy.sh
# Pulls latest code and binary from GitHub, deploys to LXC.
set -euo pipefail

REPO_DIR="/home/sites/provisioning.snorp.dev"
DEPLOY_DIR="/opt/provisioner"
SERVE_ROOT="/var/www/html"
GITHUB_REPO="sn0rp/provisioning.snorp.dev"
LOG="/var/log/provisioner-deploy.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "=== deploy started ==="

cd "$REPO_DIR"
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
  log "No code changes."
else
  log "Pulling code changes..."
  git pull origin main
fi

LATEST_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/provisioner-linux-amd64"
CURRENT_HASH=""
[ -f "$DEPLOY_DIR/provisioner" ] && CURRENT_HASH=$(sha256sum "$DEPLOY_DIR/provisioner" | cut -d' ' -f1)

log "Checking for new binary..."
wget -q "$LATEST_URL" -O /tmp/provisioner-new
NEW_HASH=$(sha256sum /tmp/provisioner-new | cut -d' ' -f1)

if [ "$CURRENT_HASH" != "$NEW_HASH" ]; then
  log "Binary changed, deploying..."
  mkdir -p "$DEPLOY_DIR"
  mv /tmp/provisioner-new "$DEPLOY_DIR/provisioner"
  chmod +x "$DEPLOY_DIR/provisioner"
  systemctl restart provisioner
  log "Provisioner restarted."
else
  rm /tmp/provisioner-new
  log "Binary unchanged."
fi

log "Syncing boot.cfg..."
cp "$REPO_DIR/boot/boot.cfg" "$SERVE_ROOT/boot.cfg"

log "=== deploy complete ==="