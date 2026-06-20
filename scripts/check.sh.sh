H
#!/bin/bash
# check.sh — Valida o ambiente antes de subir os containers
 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
 
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; ERRORS=$((ERRORS+1)); }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
 
ERRORS=0
echo "═══════════════════════════════════════"
echo "  PowerBook G4 — Validação de Ambiente"
echo "═══════════════════════════════════════"
 
# Arquivos de boot
[ -f www/debian-powerpc/vmlinuz ]  && ok "vmlinuz encontrado"   || fail "vmlinuz ausente — rode ./scripts/download-boot-files.sh"
[ -f www/debian-powerpc/initrd.gz ] && ok "initrd.gz encontrado" || fail "initrd.gz ausente — rode ./scripts/download-boot-files.sh"
[ -f www/preseed.cfg ]              && ok "preseed.cfg encontrado" || fail "preseed.cfg ausente"
 
# Docker
docker info &>/dev/null && ok "Docker está rodando" || fail "Docker não está rodando — inicie o serviço"
 
# Mirror
HTTP=$(curl -sL -o /dev/null -w "%{http_code}" "http://ftp.ports.debian.org/debian-ports/dists/sid/InRelease")
[ "$HTTP" = "200" ] && ok "Mirror ftp.ports.debian.org respondendo (HTTP 200)" || fail "Mirror não responde (HTTP $HTTP)"
 
# NAT
grep -q "1" /proc/sys/net/ipv4/ip_forward 2>/dev/null && ok "IP forwarding ativo" || warn "IP forwarding inativo — rode sudo ./scripts/setup-nat.sh"
 
echo "═══════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}✅ Ambiente pronto para deploy!${NC}"
  echo "   Execute: docker compose up -d"
else
  echo -e "${RED}❌ $ERRORS problema(s) encontrado(s) — corrija antes de continuar.${NC}"
fi
echo "═══════════════════════════════════════"
 