#!/bin/bash
# download-boot-files.sh — Baixa vmlinuz e initrd.gz do mirror oficial

set -e
MIRROR="http://ftp.ports.debian.org/debian-ports"
DEST="www/debian-powerpc"
BASE="${MIRROR}/dists/sid/main/installer-powerpc/current/images/netboot"

echo "🔽 Baixando arquivos de boot do Debian Ports (PowerPC)..."
mkdir -p "$DEST"

wget -c --show-progress -O "$DEST/vmlinuz"   "${BASE}/vmlinuz"
wget -c --show-progress -O "$DEST/initrd.gz" "${BASE}/initrd.gz"

echo "✅ Download concluído:"
ls -lh "$DEST/"