#!/bin/bash
# setup-nat.sh — Ativa IP forwarding e NAT entre Wi-Fi e Ethernet

source .env 2>/dev/null || { echo "❌ Arquivo .env não encontrado"; exit 1; }

echo "🔧 Ativando IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "🔧 Configurando NAT (${LAN_INTERFACE} ↔ ${WAN_INTERFACE})..."
iptables -t nat -A POSTROUTING -o "${WAN_INTERFACE}" -j MASQUERADE
iptables -A FORWARD -i "${LAN_INTERFACE}" -o "${WAN_INTERFACE}" -j ACCEPT
iptables -A FORWARD -i "${WAN_INTERFACE}" -o "${LAN_INTERFACE}" \
  -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "✅ NAT ativo. PowerBook G4 pode acessar a internet via ${WAN_INTERFACE}"
ip route show