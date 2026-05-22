#!/usr/bin/env bash
# scripts/update-isos.sh
# Run manually to update ISOs. Not cronned - URLs are too unstable.
# Usage: ./scripts/update-isos.sh [distro]
# Example: ./scripts/update-isos.sh debian
# No argument = update everything
set -euo pipefail

ISO_DIR="/var/www/html/isos"
LOG="/var/log/iso-update.log"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

fetch() {
  local name="$1" dest="$2" url="$3"
  log "Fetching ${name}..."
  if wget -q --show-progress --user-agent="$UA" -O "${dest}.tmp" "$url"; then
    mv "${dest}.tmp" "$dest"
    log "OK: ${name} -> ${dest}"
  else
    rm -f "${dest}.tmp"
    log "FAILED: ${name} (keeping existing if any)"
  fi
}

mkdir -p "$ISO_DIR"/{debian,ubuntu,arch,nixos,alpine,kali,sysrescue,memtest,dban,trisquel,guix,parabola,pureos,amogos,nyarch,templeos}

TARGET="${1:-all}"

run() {
  local name="$1"
  [ "$TARGET" = "all" ] || [ "$TARGET" = "$name" ]
}

run debian   && fetch "Debian 13"        "$ISO_DIR/debian/debian.iso"     "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.5.0-amd64-netinst.iso"
run ubuntu   && fetch "Ubuntu 26.04"     "$ISO_DIR/ubuntu/ubuntu.iso"     "https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso"
run arch     && fetch "Arch Linux"       "$ISO_DIR/arch/arch.iso"         "https://mirrors.mit.edu/archlinux/iso/2026.05.01/archlinux-2026.05.01-x86_64.iso"
run nixos    && fetch "NixOS 25.11"      "$ISO_DIR/nixos/nixos.iso"       "https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso"
run alpine   && fetch "Alpine 3.23"      "$ISO_DIR/alpine/alpine.iso"     "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.4-x86_64.iso"
run kali     && fetch "Kali 2026.1"      "$ISO_DIR/kali/kali.iso"         "https://cdimage.kali.org/kali-2026.1/kali-linux-2026.1-installer-amd64.iso"
run sysrescue && fetch "SystemRescue 13" "$ISO_DIR/sysrescue/sysrescue.iso" "https://cytranet-dal.dl.sourceforge.net/project/systemrescuecd/sysresccd-x86/13.00/systemrescue-13.00-amd64.iso"
run memtest  && fetch "Memtest86+"       "$ISO_DIR/memtest/memtest.iso"   "https://www.memtest.org/download/v7.20/mt86plus_7.20_64.iso.zip"
run dban     && fetch "DBAN"             "$ISO_DIR/dban/dban.iso"         "https://sourceforge.net/projects/dban/files/dban/dban-2.3.0/dban-2.3.0_i586.iso"
run trisquel && fetch "Trisquel 12 KDE"  "$ISO_DIR/trisquel/trisquel.iso" "https://mirrors.ocf.berkeley.edu/trisquel-images/triskel_12.0_amd64.iso"
run guix     && fetch "Guix 1.5"         "$ISO_DIR/guix/guix.iso"         "https://ftpmirror.gnu.org/gnu/guix/guix-system-install-1.5.0.x86_64-linux.iso"
run parabola && fetch "Parabola"         "$ISO_DIR/parabola/parabola.iso" "https://redirector.parabola.nu/iso/x86_64-systemd-cli-2022.04/parabola-x86_64-systemd-cli-2022.04-netinstall.iso"
run pureos   && fetch "PureOS 11 KDE"    "$ISO_DIR/pureos/pureos.iso"     "https://storage.puri.sm/pureos/images/crimson/2026.05/plasma/pureos-11-plasma-live-20260515_amd64.iso"
run amogos   && fetch "AmogOS 1.5"       "$ISO_DIR/amogos/amogos.iso"     "https://github.com/Amog-OS/AmogOS/releases/download/x64-1.5.0/AmogOS-1.5.0-x86_64.iso"
run nyarch   && fetch "Nyarch KDE"       "$ISO_DIR/nyarch/nyarch.iso"     "https://geomirror.nyarchlinux.moe/Nyarch-KDE-26.04.iso"
run templeos && fetch "TempleOS"         "$ISO_DIR/templeos/templeos.iso" "https://templeos.net/htdocs/wp-content/uploads/TempleOS/TOS_Distro.ISO"

# Memtest comes as a zip - unzip it
if [ -f "$ISO_DIR/memtest/memtest.iso" ] && file "$ISO_DIR/memtest/memtest.iso" | grep -q "Zip"; then
  log "Extracting Memtest zip..."
  cd "$ISO_DIR/memtest"
  unzip -o memtest.iso "*.iso" 2>/dev/null && mv *.iso memtest_extracted.iso && mv memtest_extracted.iso memtest.iso || true
fi

log "=== ISO update complete ==="
log "Disk usage: $(du -sh $ISO_DIR)"