#!/usr/bin/env bash
# scripts/update-isos.sh
# Updates netboot kernel/initrd files and tools.
# Uses 7z for extraction - no loop mount required.
# Usage: ./update-isos.sh [distro|all]
set -euo pipefail

BASE_DIR="/var/www/html"
NB_DIR="$BASE_DIR/netboot"
ISO_DIR="$BASE_DIR/isos"
TOOLS_DIR="$BASE_DIR/tools"
LOG="/var/log/iso-update.log"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

fetch() {
  local name="$1" dest="$2" url="$3"
  log "Fetching ${name}..."
  mkdir -p "$(dirname "$dest")"
  if wget -q --show-progress --user-agent="$UA" -O "${dest}.tmp" "$url"; then
    mv "${dest}.tmp" "$dest"
    log "OK: ${name}"
  else
    rm -f "${dest}.tmp"
    log "FAILED: ${name}"
    return 1
  fi
}

extract() {
  local name="$1" iso="$2" outdir="$3"
  shift 3
  local files=("$@")
  log "Extracting ${name}..."
  mkdir -p "$outdir"
  7z e "$iso" -o"${outdir}/" "${files[@]}" -r -y > /dev/null
  log "OK: ${name}"
}

TARGET="${1:-all}"
run() { [ "$TARGET" = "all" ] || [ "$TARGET" = "$1" ]; }

# Direct netboot downloads (no ISO needed)

run debian && {
  BASE="https://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/debian-installer/amd64"
  mkdir -p "$NB_DIR/debian"
  fetch "Debian linux"   "$NB_DIR/debian/linux"     "$BASE/linux"
  fetch "Debian initrd"  "$NB_DIR/debian/initrd.gz" "$BASE/initrd.gz"
}

run alpine && {
  BASE="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/netboot"
  mkdir -p "$NB_DIR/alpine"
  fetch "Alpine vmlinuz"   "$NB_DIR/alpine/vmlinuz"    "$BASE/vmlinuz-lts"
  fetch "Alpine initramfs" "$NB_DIR/alpine/initramfs"  "$BASE/initramfs-lts"
  fetch "Alpine modloop"   "$NB_DIR/alpine/modloop"    "$BASE/modloop-lts"
}

run kali && {
  BASE="https://http.kali.org/kali/dists/kali-rolling/main/installer-amd64/current/images/netboot/debian-installer/amd64"
  mkdir -p "$NB_DIR/kali"
  fetch "Kali linux"   "$NB_DIR/kali/linux"     "$BASE/linux"
  fetch "Kali initrd"  "$NB_DIR/kali/initrd.gz" "$BASE/initrd.gz"
}

# ISO download + extraction

run ubuntu && {
  ISO="/tmp/ubuntu-update.iso"
  fetch "Ubuntu ISO" "$ISO" "https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso"
  mkdir -p "$NB_DIR/ubuntu"
  extract "Ubuntu vmlinuz" "$ISO" "$NB_DIR/ubuntu" "casper/vmlinuz"
  extract "Ubuntu initrd"  "$ISO" "$NB_DIR/ubuntu" "casper/initrd"
  rm -f "$ISO"
}

run trisquel && {
  ISO="/tmp/trisquel-update.iso"
  fetch "Trisquel ISO" "$ISO" \
    "https://mirrors.ocf.berkeley.edu/trisquel-images/triskel_12.0_amd64.iso"
  mkdir -p "$NB_DIR/trisquel"
  extract "Trisquel vmlinuz" "$ISO" "$NB_DIR/trisquel" "casper/vmlinuz"
  extract "Trisquel initrd"  "$ISO" "$NB_DIR/trisquel" "casper/initrd"
  mv "$NB_DIR/trisquel/vmlinuz" "$NB_DIR/trisquel/linux" 2>/dev/null || true
  mv "$NB_DIR/trisquel/initrd"  "$NB_DIR/trisquel/initrd.gz" 2>/dev/null || true
  rm -f "$ISO"
}

run pureos && {
  ISO="/tmp/pureos-update.iso"
  fetch "PureOS ISO" "$ISO" \
    "https://storage.puri.sm/pureos/images/crimson/2026.05/plasma/pureos-11-plasma-live-20260515_amd64.iso"
  mkdir -p "$NB_DIR/pureos"
  extract "PureOS vmlinuz" "$ISO" "$NB_DIR/pureos" "casper/vmlinuz"
  extract "PureOS initrd"  "$ISO" "$NB_DIR/pureos" "casper/initrd.img"
  mv "$NB_DIR/pureos/vmlinuz"    "$NB_DIR/pureos/linux"     2>/dev/null || true
  mv "$NB_DIR/pureos/initrd.img" "$NB_DIR/pureos/initrd.gz" 2>/dev/null || true
  rm -f "$ISO"
}

run amogos && {
  # Dead project - check if URL still works before updating
  ISO="/tmp/amogos-update.iso"
  fetch "AmogOS ISO" "$ISO" \
    "https://github.com/Amog-OS/AmogOS/releases/download/x64-1.5.0/AmogOS-1.5.0-x86_64.iso"
  mkdir -p "$NB_DIR/amogos"
  extract "AmogOS vmlinuz" "$ISO" "$NB_DIR/amogos" "linux/boot/vmlinuz"
  extract "AmogOS initrd"  "$ISO" "$NB_DIR/amogos" "linux/boot/initrfs.img"
  mv "$NB_DIR/amogos/vmlinuz"     "$NB_DIR/amogos/linux"  2>/dev/null || true
  mv "$NB_DIR/amogos/initrfs.img" "$NB_DIR/amogos/initrd" 2>/dev/null || true
  rm -f "$ISO"
}

run dban && {
  if [ ! -f "$TOOLS_DIR/dban/dban.bzi" ]; then
    ISO="/tmp/dban-update.iso"
    fetch "DBAN ISO" "$ISO" \
      "https://sourceforge.net/projects/dban/files/dban/dban-2.3.0/dban-2.3.0_i586.iso/download"
    mkdir -p "$TOOLS_DIR/dban"
    extract "DBAN kernel" "$ISO" "$TOOLS_DIR/dban" "DBAN.BZI"
    mv "$TOOLS_DIR/dban/DBAN.BZI" "$TOOLS_DIR/dban/dban.bzi" 2>/dev/null || true
    rm -f "$ISO"
  else
    log "DBAN: already present, skipping (abandoned project)"
  fi
}

run proxmox && {
  ISO="/tmp/proxmox-update.iso"
  fetch "Proxmox VE ISO" "$ISO" \
    "https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso"
  mkdir -p "$NB_DIR/proxmox"
  extract "Proxmox linux26" "$ISO" "$NB_DIR/proxmox" "boot/linux26"
  extract "Proxmox initrd"  "$ISO" "$NB_DIR/proxmox" "boot/initrd.img"
  rm -f "$ISO"
}

run nixos && log "NixOS: chains to netboot.nixos.org, no local files needed"

log "=== update complete ==="
log "Disk usage: $(du -sh $NB_DIR $ISO_DIR $TOOLS_DIR 2>/dev/null | tr '\n' ' ')"