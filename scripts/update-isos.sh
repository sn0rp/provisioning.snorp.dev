#!/usr/bin/env bash
# scripts/update-isos.sh
# Updates netboot kernel/initrd files and tools from known-good sources.
# ISOs are extracted using 7z; no loop mount required.
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
  log "Extracting ${name} from $(basename $iso)..."
  mkdir -p "$outdir"
  7z e "$iso" -o"${outdir}/" "${files[@]}" -r -y > /dev/null
  log "OK: ${name} extracted"
}

TARGET="${1:-all}"
run() { [ "$TARGET" = "all" ] || [ "$TARGET" = "$1" ]; }

# =============================================================================
# Distros with official netboot kernel+initrd (direct download, no ISO needed)
# =============================================================================

run debian && {
  BASE="https://deb.debian.org/debian/dists/trixie/main/installer-amd64/current/images/netboot/debian-installer/amd64"
  mkdir -p "$NB_DIR/debian"
  fetch "Debian linux"   "$NB_DIR/debian/linux"     "$BASE/linux"
  fetch "Debian initrd"  "$NB_DIR/debian/initrd.gz" "$BASE/initrd.gz"
}

run ubuntu && {
  # Ubuntu desktop live ISO - download and extract casper kernel+initrd
  ISO="/tmp/ubuntu-update.iso"
  fetch "Ubuntu ISO" "$ISO" "https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso"
  mkdir -p "$NB_DIR/ubuntu"
  extract "Ubuntu vmlinuz" "$ISO" "$NB_DIR/ubuntu" "casper/vmlinuz"
  extract "Ubuntu initrd"  "$ISO" "$NB_DIR/ubuntu" "casper/initrd"
  rm -f "$ISO"
}

run arch && {
  BASE="https://geo.mirror.pkgbuild.com/iso/latest/arch/boot/x86_64"
  mkdir -p "$NB_DIR/arch"
  fetch "Arch vmlinuz"   "$NB_DIR/arch/linux"      "$BASE/vmlinuz-linux"
  fetch "Arch initrd"    "$NB_DIR/arch/initrd.img"  "$BASE/initramfs-linux.img"
  # Arch also needs the airootfs squashfs for live boot
  # This is large (~700MB) and changes monthly - only update if needed
  log "Note: Arch airootfs.sfs must be updated manually from the ISO if needed"
}

run alpine && {
  # Alpine publishes dedicated netboot files
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

# =============================================================================
# Distros requiring ISO download + extraction
# These don't publish standalone netboot files
# =============================================================================

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

run parabola && {
  ISO="/tmp/parabola-update.iso"
  # Find current ISO at https://redirector.parabola.nu/iso/
  fetch "Parabola ISO" "$ISO" \
    "https://redirector.parabola.nu/iso/x86_64-systemd-cli-2022.04/parabola-x86_64-systemd-cli-2022.04-netinstall.iso"
  mkdir -p "$NB_DIR/parabola"
  extract "Parabola vmlinuz"      "$ISO" "$NB_DIR/parabola" "parabola/boot/x86_64/vmlinuz"
  extract "Parabola parabolaiso"  "$ISO" "$NB_DIR/parabola" "parabola/boot/x86_64/parabolaiso.img"
  extract "Parabola squashfs"     "$ISO" "$NB_DIR/parabola" "parabola/x86_64/root-image.fs.sfs"
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

run sysrescue && {
  ISO="/tmp/sysrescue-update.iso"
  fetch "SystemRescueCD ISO" "$ISO" \
    "https://cytranet-dal.dl.sourceforge.net/project/systemrescuecd/sysresccd-x86/13.00/systemrescue-13.00-amd64.iso"
  mkdir -p "$NB_DIR/sysrescue"
  extract "SysRescue vmlinuz"    "$ISO" "$NB_DIR/sysrescue" "sysresccd/boot/x86_64/vmlinuz"
  extract "SysRescue initrd"     "$ISO" "$NB_DIR/sysrescue" "sysresccd/boot/x86_64/sysresccd.img"
  extract "SysRescue airootfs"   "$ISO" "$NB_DIR/sysrescue" "sysresccd/x86_64/airootfs.sfs"
  rm -f "$ISO"
}

run amogos && {
  # Dead project - URL unlikely to change
  ISO="/tmp/amogos-update.iso"
  fetch "AmogOS ISO" "$ISO" \
    "https://github.com/Amog-OS/AmogOS/releases/download/x64-1.5.0/AmogOS-1.5.0-x86_64.iso"
  mkdir -p "$NB_DIR/amogos"
  extract "AmogOS vmlinuz" "$ISO" "$NB_DIR/amogos" "linux/boot/vmlinuz"
  extract "AmogOS initrd"  "$ISO" "$NB_DIR/amogos" "linux/boot/initrfs.img"
  mv "$NB_DIR/amogos/vmlinuz"    "$NB_DIR/amogos/linux" 2>/dev/null || true
  mv "$NB_DIR/amogos/initrfs.img" "$NB_DIR/amogos/initrd" 2>/dev/null || true
  rm -f "$ISO"
}

run nyarch && {
  ISO="/tmp/nyarch-update.iso"
  fetch "Nyarch ISO" "$ISO" \
    "https://geomirror.nyarchlinux.moe/Nyarch-KDE-26.04.iso"
  mkdir -p "$NB_DIR/nyarch"
  extract "Nyarch vmlinuz" "$ISO" "$NB_DIR/nyarch" "arch/boot/x86_64/vmlinuz-linux"
  extract "Nyarch initrd"  "$ISO" "$NB_DIR/nyarch" "arch/boot/x86_64/initramfs-linux.img"
  # Nyarch also needs its airootfs squashfs
  extract "Nyarch airootfs" "$ISO" "$NB_DIR/nyarch" "arch/x86_64/airootfs.sfs" 2>/dev/null || \
    log "Warning: Nyarch airootfs not found at expected path - check ISO structure"
  mv "$NB_DIR/nyarch/vmlinuz-linux"       "$NB_DIR/nyarch/vmlinuz"      2>/dev/null || true
  mv "$NB_DIR/nyarch/initramfs-linux.img" "$NB_DIR/nyarch/initramfs.img" 2>/dev/null || true
  rm -f "$ISO"
}

# =============================================================================
# Tools (DBAN - extract kernel from ISO)
# =============================================================================

run dban && {
  # DBAN hasn't been updated since 2015 - only re-run if tools/dban/dban.bzi is missing
  if [ ! -f "$TOOLS_DIR/dban/dban.bzi" ]; then
    ISO="/tmp/dban-update.iso"
    fetch "DBAN ISO" "$ISO" \
      "https://sourceforge.net/projects/dban/files/dban/dban-2.3.0/dban-2.3.0_i586.iso/download"
    mkdir -p "$TOOLS_DIR/dban"
    extract "DBAN kernel" "$ISO" "$TOOLS_DIR/dban" "DBAN.BZI"
    mv "$TOOLS_DIR/dban/DBAN.BZI" "$TOOLS_DIR/dban/dban.bzi" 2>/dev/null || true
    rm -f "$ISO"
  else
    log "DBAN: already present, skipping (project abandoned)"
  fi
}

# =============================================================================
# NixOS - no local files needed, chains to netboot.nixos.org
# =============================================================================
run nixos && log "NixOS: uses chain boot to netboot.nixos.org, no local files needed"

log "=== update complete ==="
log "Disk usage: netboot=$(du -sh $NB_DIR 2>/dev/null | cut -f1) isos=$(du -sh $ISO_DIR 2>/dev/null | cut -f1) tools=$(du -sh $TOOLS_DIR 2>/dev/null | cut -f1)"