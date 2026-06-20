# 🍏 PowerBook G4 — Instalação Automatizada via Rede (PXE/TFTP)

> **Provisionamento headless do Debian Ports (PowerPC 32-bit) em hardware Apple legado via boot de rede, containers Docker e preseed automatizado.**

![PowerBook G4 17"](https://github.com/user-attachments/assets/c4e8f3de-fe61-4e43-8089-65a16f89a171)

---

## 📑 Índice

- [História e Motivação](#-1-história-e-motivação)
- [O Problema Técnico](#-2-o-problema-técnico)
- [Arquitetura da Solução](#-3-arquitetura-da-solução)
- [Pré-requisitos](#-4-pré-requisitos)
- [Estrutura do Repositório](#-5-estrutura-do-repositório)
- [Configuração do Servidor](#-6-configuração-do-servidor-dell-precision-5510)
- [Boot no PowerBook G4](#-7-boot-no-powerbook-g4)
- [Fluxo Completo de Deploy](#-8-fluxo-completo-de-deploy)
- [Resolução de Problemas](#-9-resolução-de-problemas)
- [Referências](#-10-referências)
---
## 📖 1. História e Motivação

### A Era de Ouro do PowerPC

No início dos anos 2000, a arquitetura RISC **PowerPC** — desenvolvida pela aliança **AIM** (Apple, IBM e Motorola) — representava o topo absoluto do desempenho computacional em portáteis, superando processadores x86 em processamento por ciclo de clock.

Em janeiro de **2003**, a Apple revolucionou o mercado ao lançar o **PowerBook G4 Alumínio de 17 polegadas**: o primeiro notebook de 17" do mundo, com carcaça de alumínio aeronáutico, teclado retroiluminado por sensores de luz ambiente, porta FireWire 800, AirPort Extreme integrado e tela de alta densidade (até 1680×1050).

Em **2006**, a transição para processadores Intel encerrou essa linhagem, deixando esses equipamentos estagnados no Mac OS X 10.5 Leopard — sem atualizações de segurança há quase **duas décadas**.

### Por que restaurar em 2026?

Restaurar este PowerBook G4 vai muito além da nostalgia. É um manifesto de:

| Princípio | Descrição |
|---|---|
| 🌱 **Green IT** | Evitar descarte de hardware com estrutura física intacta e tela profissional de grandes proporções |
| 🔒 **Soberania Tecnológica** | Devolver autonomia e atualizações de segurança a um hardware abandonado pelo fabricante |
| 🛠️ **Preservação Digital** | Manter operacional um marco da engenharia móvel dos anos 2000 |
| 🧠 **Desafio de Engenharia** | Superar barreiras de um ecossistema sem suporte oficial há quase 20 anos |

---

## 🎯 2. O Problema Técnico

Instalar um Linux moderno em um Mac **NewWorld** (arquitetura OpenFirmware) apresenta quatro desafios críticos em camadas:

```
┌─────────────────────────────────────────────────────────┐
│               CAMADAS DO PROBLEMA                       │
├──────────┬──────────────────────────────────────────────┤
│ Camada 1 │ Hardware físico degradado                    │
│          │ → SuperDrive com falha de leitura em mídias  │
│          │   gravadas modernamente                      │
├──────────┼──────────────────────────────────────────────┤
│ Camada 2 │ Boot USB instável no OpenFirmware            │
│          │ → Suporte nativo incompleto para pendrives   │
│          │   USB, resultando em falhas de leitura       │
├──────────┼──────────────────────────────────────────────┤
│ Camada 3 │ Repositórios isolados (debian-ports)         │
│          │ → PowerPC 32-bit movido para unstable/sid;   │
│          │   espelhos padrão do Debian falham           │
├──────────┼──────────────────────────────────────────────┤
│ Camada 4 │ Firmwares proprietários                      │
│          │ → GPU ATI/NVIDIA e Wi-Fi exigem firmware     │
│          │   non-free injetado durante a instalação     │
└──────────┴──────────────────────────────────────────────┘
```

### Por que boot de rede (PXE)?

O boot de rede via **TFTP + DHCP** contorna completamente as camadas 1 e 2, eliminando dependência de mídia física e garantindo um canal confiável de provisionamento via cabo Ethernet.

---

## 🏗️ 3. Arquitetura da Solução

### Visão geral

```
                        INTERNET
                           │
                     ┌─────┴──────┐
                     │  Wi-Fi     │
                     │ wlp2s0     │  Dell Precision 5510
                     │            │  (Servidor de Deploy)
                     │  Ethernet  │
                     │ enp62s0u1u2│
                     └─────┬──────┘
                           │ Cabo RJ45 direto
                           │ 192.168.1.0/24
                     ┌─────┴──────┐
                     │ PowerBook  │
                     │    G4      │
                     │ (Cliente)  │
                     └────────────┘
```

### Containers Docker no servidor

```
┌─────────────────────────────────────────────────────┐
│              Docker Compose (host)                  │
│                                                     │
│  ┌──────────────────────┐  ┌─────────────────────┐  │
│  │   powerg4-pxe-tftp   │  │  powerg4-web-server │  │
│  │   (Alpine/dnsmasq)   │  │   (nginx:alpine)    │  │
│  │                      │  │                     │  │
│  │  • DHCP :67/udp      │  │  • HTTP :80/tcp     │  │
│  │  • TFTP :69/udp      │  │  • Serve preseed    │  │
│  │  • Envia vmlinuz     │  │  • Serve vmlinuz    │  │
│  │  • Envia initrd.gz   │  │  • Serve initrd.gz  │  │
│  └──────────────────────┘  └─────────────────────┘  │
│           │                          │               │
│           └──────────┬───────────────┘               │
│                      │ volume: ./www                 │
└──────────────────────┼───────────────────────────────┘
                       │
              ┌────────┴────────┐
              │   ./www/        │
              │  preseed.cfg    │
              │  debian-powerpc/│
              │  ├── vmlinuz    │
              │  └── initrd.gz  │
              └─────────────────┘
```

### Fluxo de rede (NAT/IPTables)

O Dell Precision atua como **roteador NAT** entre o PowerBook G4 (rede cabeada isolada `192.168.1.x`) e a Internet (Wi-Fi):

```bash
# Mascaramento ativado no host — PowerBook acessa internet via Precision
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE
iptables -A FORWARD -i enp62s0u1u2 -o wlp2s0 -j ACCEPT
iptables -A FORWARD -i wlp2s0 -o enp62s0u1u2 -m state \
  --state RELATED,ESTABLISHED -j ACCEPT
```

---

## ⚙️ 4. Pré-requisitos

### Hardware

| Equipamento | Função |
|---|---|
| Dell Precision 5510 (ou similar) | Servidor de deploy — roda Docker e o NAT |
| PowerBook G4 (qualquer modelo alumínio) | Máquina alvo da instalação |
| Cabo Ethernet RJ45 | Conexão direta entre as duas máquinas |

### Software no servidor (Dell)

```bash
# Docker e Docker Compose
sudo apt install docker.io docker-compose-v2 -y

# Ferramentas de rede
sudo apt install wget curl iptables -y
```

### Verificar conectividade do mirror antes de tudo

```bash
# Confirmar que o mirror oficial responde (deve retornar HTTP 200)
curl -sL -o /dev/null -w "HTTP %{http_code}\n" \
  "http://ftp.ports.debian.org/debian-ports/dists/sid/InRelease"
```

---

## 📁 5. Estrutura do Repositório

```text
powerg4_install/
├── docker-compose.yml          # Orquestração dos containers DHCP/TFTP e HTTP
├── .env                        # Variáveis de rede (IPs, interfaces) — NÃO commitar
├── .env.example                # Modelo de variáveis para novos usuários
├── .gitignore                  # Exclui binários pesados (vmlinuz, initrd.gz)
├── config/
│   └── dnsmasq.conf            # Configuração do servidor DHCP + TFTP
├── www/
│   ├── preseed.cfg             # Respostas automáticas do instalador Debian
│   └── debian-powerpc/
│       ├── vmlinuz             # Kernel de instalação (baixar via script)
│       └── initrd.gz           # Ramdisk inicial (baixar via script)
├── scripts/
│   ├── setup-nat.sh            # Ativa roteamento IP e NAT no host
│   ├── download-boot-files.sh  # Baixa vmlinuz e initrd.gz do mirror oficial
│   └── check.sh                # Valida ambiente antes de subir os containers
└── README.md
```

---

## 🖥️ 6. Configuração do Servidor (Dell Precision 5510)

### Passo 1 — Clonar o repositório

```bash
git clone https://github.com/SEU_USUARIO/powerg4_install.git
cd powerg4_install
```

### Passo 2 — Configurar variáveis de rede

```bash
cp .env.example .env
nano .env
```

Conteúdo do `.env` (ajuste para sua rede):

```env
# Interface conectada ao PowerBook G4 (cabo Ethernet)
LAN_INTERFACE=enp62s0u1u2

# Interface com acesso à internet (Wi-Fi)
WAN_INTERFACE=wlp2s0

# IP fixo do servidor na rede local
SERVER_IP=192.168.1.1

# Faixa DHCP para o PowerBook G4
DHCP_START=192.168.1.200
DHCP_END=192.168.1.220
```

### Passo 3 — Baixar os arquivos de boot

```bash
chmod +x scripts/download-boot-files.sh
./scripts/download-boot-files.sh
```

> O script baixa `vmlinuz` e `initrd.gz` do mirror oficial `ftp.ports.debian.org` — **confirmado HTTP 200**.

### Passo 4 — Validar o ambiente

```bash
chmod +x scripts/check.sh
./scripts/check.sh
```

Saída esperada:
```
✅ vmlinuz encontrado
✅ initrd.gz encontrado
✅ preseed.cfg encontrado
✅ Docker está rodando
✅ Mirror ftp.ports.debian.org respondendo (HTTP 200)
✅ Ambiente pronto para deploy
```

### Passo 5 — Ativar NAT (roteamento para internet)

```bash
sudo chmod +x scripts/setup-nat.sh
sudo ./scripts/setup-nat.sh
```

### Passo 6 — Subir os containers

```bash
docker compose up -d
docker compose logs -f   # acompanhar em tempo real
```

---

## 🍎 7. Boot no PowerBook G4

### Passo 1 — Acessar o OpenFirmware

Ao ligar o PowerBook G4, pressione imediatamente as **4 teclas juntas**:

```
⌘ Cmd  +  ⌥ Option  +  O  +  F
```

Aguarde o prompt do OpenFirmware:
```
Welcome to Open Firmware
To continue booting, type "mac-boot" and press return.
0 >
```

### Passo 2 — Comando de boot via rede

No prompt `0 >`, digite o comando abaixo (substitua `192.168.1.1` pelo IP do seu servidor):

```
boot enet:0,yaboot
```

Ou com preseed via HTTP:

```
boot enet:0,yaboot url=http://192.168.1.1/preseed.cfg \
  netcfg/get_ipaddress=192.168.1.201 \
  netcfg/get_gateway=192.168.1.1 \
  netcfg/get_nameservers=8.8.8.8 \
  netcfg/disable_dhcp=false
```

### Passo 3 — Acompanhar a instalação

A instalação é **totalmente automatizada** pelo `preseed.cfg`. O PowerBook irá:

1. Receber IP via DHCP do dnsmasq
2. Baixar `vmlinuz` e `initrd.gz` via TFTP
3. Iniciar o kernel de instalação
4. Buscar o `preseed.cfg` via HTTP no nginx
5. Particionar o disco automaticamente (Apple Partition Map)
6. Baixar pacotes do `ftp.ports.debian.org` via NAT
7. Instalar o ambiente MATE e reiniciar

---

## 🔄 8. Fluxo Completo de Deploy

```
╔══════════════════════════════════════════════════════════════════╗
║                    FLUXO DE DEPLOY                               ║
╠══════════════╦═══════════════════════════════════════════════════╣
║ SERVIDOR     ║ POWERBOOK G4                                      ║
║ (Precision)  ║                                                   ║
╠══════════════╬═══════════════════════════════════════════════════╣
║              ║                                                   ║
║ 1. Inicia    ║                                                   ║
║    Docker    ║                                                   ║
║    Compose   ║                                                   ║
║    ↓         ║                                                   ║
║ 2. dnsmasq   ║                                                   ║
║    ativo     ║                                                   ║
║    :67/:69   ║                                                   ║
║    ↓         ║                                                   ║
║ 3. nginx     ║                                                   ║
║    ativo     ║                                                   ║
║    :80       ║                                                   ║
║    ↓         ║                          ║                        ║
║ 4. NAT       ║                          ║                        ║
║    ativo     ║                          ║                        ║
║              ║  5. Boot OpenFirmware    ║                        ║
║              ║     Cmd+Opt+O+F          ║                        ║
║              ║     ↓                   ║                        ║
║              ║  6. boot enet:0,yaboot  ║                        ║
║              ║                         ║                        ║
║ 7. DHCP ◄───╬──── Broadcast DHCP ─────╝                        ║
║    Responde  ║                                                   ║
║    IP+Gateway║                                                   ║
║    ↓         ║                                                   ║
║ 8. TFTP ────╬───► vmlinuz + initrd.gz                           ║
║    Envia     ║                                                   ║
║              ║  9. Kernel inicia                                 ║
║              ║                                                   ║
║10. HTTP ◄───╬──── GET /preseed.cfg                              ║
║    Nginx     ║                                                   ║
║    200 OK ──╬───► preseed.cfg                                   ║
║              ║                                                   ║
║              ║ 11. Instalação                                    ║
║              ║     automatizada                                  ║
║              ║                                                   ║
║12. NAT ◄────╬──── Tráfego de pacotes                            ║
║    Roteia    ║     Debian Ports                                  ║
║    Internet ─╬───► Pacotes instalados                           ║
║              ║                                                   ║
║              ║ 13. Reboot ✅                                     ║
╚══════════════╩═══════════════════════════════════════════════════╝
```

---

## 🔧 9. Resolução de Problemas

### PowerBook não recebe IP via DHCP

```bash
# Verificar se dnsmasq está rodando
docker compose ps
docker compose logs powerg4-pxe-tftp

# Verificar interface de rede correta no .env
ip link show
```

### Mirror GPG inválido durante instalação

O mirror `ftp.ports.debian.org` está confirmado como funcional. Caso apresente erro de assinatura, o `preseed.cfg` já inclui:

```
d-i debian-installer/allow_unauthenticated boolean true
```

### `/boot/grub` montado como read-only após instalação

Problema conhecido no driver HFS do Linux. Solução:

```bash
# No PowerBook após boot, como root:
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umount /boot/grub
mount -t hfs -o rw /dev/sda2 /boot/grub
dpkg --configure -a
```

### OpenFirmware não encontra servidor

Verificar com comando mais explícito:

```
setenv boot-device enet:192.168.1.1,vmlinuz
setenv boot-args root=/dev/ram rw
boot
```

### Testar mirrors manualmente

```bash
# No servidor Dell, antes do deploy:
for mirror in \
  "http://ftp.ports.debian.org/debian-ports/dists/sid/InRelease" \
  "https://snapshot.debian.org/archive/debian-ports/20241101T000000Z/dists/sid/InRelease"; do
  echo -n "$mirror → "
  curl -sL -o /dev/null -w "HTTP %{http_code}\n" "$mirror"
done
```

---

## 📚 10. Referências

| Recurso | Link |
|---|---|
| Debian Ports | https://www.ports.debian.org |
| Mirror oficial PowerPC | http://ftp.ports.debian.org/debian-ports |
| Debian Preseed Reference | https://www.debian.org/releases/stable/powerpc/apb.en.html |
| OpenFirmware Boot Commands | https://wiki.debian.org/PowerPCBootProcess |
| yaboot documentation | https://yaboot.ozlabs.org |
| Void Linux PowerPC (alternativa) | https://voidlinux.org/download/#arm-platforms |

---

## 🤝 Contribuindo

Pull requests são bem-vindos. Para mudanças significativas, abra uma issue primeiro descrevendo o que deseja modificar.

## 📄 Licença

MIT — veja [LICENSE](LICENSE) para detalhes.

---

<div align="center">

**Feito com 🛠️ para preservar hardware histórico**

*PowerBook G4 Alumínio 17" — 2003/2026*

</div>
