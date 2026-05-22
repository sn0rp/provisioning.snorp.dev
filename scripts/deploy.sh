#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/home/sites/provisioning.snorp.dev"
DEPLOY_DIR="/opt/provisioner"
SERVE_ROOT="/var/www/html"
IPXE_DIR="/opt/ipxe/src"
GITHUB_REPO="sn0rp/provisioning.snorp.dev"
LOG="/var/log/provisioner-deploy.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "=== deploy started ==="

cd "$REPO_DIR"
git fetch origin master
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" = "$REMOTE" ]; then
  log "No code changes."
else
  log "Pulling code changes..."
  git pull origin master
fi

LATEST_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/provisioner-linux-amd64"
CURRENT_HASH=""
[ -f "$DEPLOY_DIR/provisioner" ] && CURRENT_HASH=$(sha256sum "$DEPLOY_DIR/provisioner" | cut -d' ' -f1)

log "Checking for new binary..."
wget -q "$LATEST_URL" -O /tmp/provisioner-new
NEW_HASH=$(sha256sum /tmp/provisioner-new | cut -d' ' -f1)

if [ "$CURRENT_HASH" != "$NEW_HASH" ]; then
  log "Binary changed, deploying..."
  mv /tmp/provisioner-new "$DEPLOY_DIR/provisioner"
  chmod +x "$DEPLOY_DIR/provisioner"
  systemctl restart provisioner
  log "Provisioner restarted."
else
  rm /tmp/provisioner-new
  log "Binary unchanged."
fi

# Rebuild iPXE bootloaders if boot.ipxe changed
IPXE_SCRIPT="$REPO_DIR/boot/boot.ipxe"
IPXE_HASH_FILE="/opt/.boot_ipxe.sha256"
CURRENT_IPXE_HASH=""
[ -f "$IPXE_HASH_FILE" ] && CURRENT_IPXE_HASH=$(cat "$IPXE_HASH_FILE")
NEW_IPXE_HASH=$(sha256sum "$IPXE_SCRIPT" | cut -d' ' -f1)

if [ "$CURRENT_IPXE_HASH" != "$NEW_IPXE_HASH" ]; then
  log "boot.ipxe changed, rebuilding iPXE bootloaders..."
  cd "$IPXE_DIR"
  make bin/undionly.kpxe EMBED="$IPXE_SCRIPT" 2>&1 | tee -a "$LOG"
  make bin-x86_64-efi/ipxe.efi EMBED="$IPXE_SCRIPT" 2>&1 | tee -a "$LOG"
  cp bin/undionly.kpxe "$SERVE_ROOT/netboot.xyz.kpxe"
  cp bin-x86_64-efi/ipxe.efi "$SERVE_ROOT/netboot.xyz.efi"
  echo "$NEW_IPXE_HASH" > "$IPXE_HASH_FILE"
  log "iPXE bootloaders rebuilt and deployed."
else
  log "boot.ipxe unchanged, skipping rebuild."
fi

log "=== deploy complete ==="