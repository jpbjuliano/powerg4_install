# 🐳 Docker — Infraestrutura de Containers

> Documentação completa dos dois containers que compõem o ambiente de deploy do PowerBook G4: servidor DHCP/TFTP (`powerg4-pxe-tftp`) e servidor HTTP (`powerg4-web-server`).

---

## 📑 Índice

- [Visão Geral](#-visão-geral)
- [Pré-requisitos](#-pré-requisitos)
- [Container 1 — powerg4-pxe-tftp](#-container-1--powerg4-pxe-tftp)
- [Container 2 — powerg4-web-server](#-container-2--powerg4-web-server)
- [docker-compose.yml explicado](#-docker-composeyml-explicado)
- [Volumes compartilhados](#-volumes-compartilhados)
- [Comandos do dia a dia](#-comandos-do-dia-a-dia)
- [Diagnóstico e logs](#-diagnóstico-e-logs)
- [Resolução de problemas](#-resolução-de-problemas)

---

## 🗺️ Visão Geral

O ambiente é composto por **dois containers leves** que operam em conjunto usando `network_mode: host` — ou seja, compartilham diretamente a interface de rede do Dell Precision, sem NAT interno do Docker:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Dell Precision 5510                          │
│                                                                 │
│  ┌───────────────────────────┐  ┌──────────────────────────┐   │
│  │   powerg4-pxe-tftp        │  │   powerg4-web-server     │   │
│  │   alpine:latest           │  │   nginx:alpine           │   │
│  │                           │  │                          │   │
│  │  ┌─────────┐ ┌─────────┐  │  │  ┌────────────────────┐ │   │
│  │  │  DHCP   │ │  TFTP   │  │  │  │     HTTP :80       │ │   │
│  │  │ :67/udp │ │ :69/udp │  │  │  │                    │ │   │
│  │  └────┬────┘ └────┬────┘  │  │  │  /preseed.cfg      │ │   │
│  │       │           │       │  │  │  /debian-powerpc/  │ │   │
│  └───────┼───────────┼───────┘  │  │   vmlinuz          │ │   │
│          │           │          │  │   initrd.gz        │ │   │
│          │     ┌─────┴──────────┼──┼────────────────────┘ │   │
│          │     │   volume: ./www│  └──────────────────────┘   │
│          │     └────────────────┘                              │
│          │                                                     │
│     enp62s0u1u2 (Ethernet — cabo direto para o PowerBook G4)  │
└──────────┼──────────────────────────────────────────────────────┘
           │
    ───────┴───────
       PowerBook G4
    (192.168.1.200)
```

---

## ⚙️ Pré-requisitos

### Instalar Docker e Docker Compose

```bash
# Instalar Docker
sudo apt install docker.io docker-compose-v2 -y

# Adicionar seu usuário ao grupo docker (evita usar sudo a todo momento)
sudo usermod -aG docker $USER
newgrp docker

# Verificar instalação
docker --version
docker compose version
```

### Verificar que o serviço está rodando

```bash
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
```

---

## 📦 Container 1 — `powerg4-pxe-tftp`

### Função

É o **coração do boot de rede**. Combina dois serviços críticos:

| Serviço | Porta | Protocolo | Função |
|---|---|---|---|
| **DHCP** | 67 | UDP | Atribui IP ao PowerBook G4 quando ele acorda na rede |
| **TFTP** | 69 | UDP | Transfere `vmlinuz` e `initrd.gz` para o PowerBook iniciar o instalador |

### Imagem base

```
alpine:latest
```

O Alpine Linux é usado porque é **extremamente leve (~5MB)** e o `dnsmasq` — que provê DHCP e TFTP simultaneamente — está disponível no repositório oficial do Alpine.

### O que acontece na inicialização do container

```bash
# Comando executado automaticamente ao subir o container:
apk add --no-cache dnsmasq && dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf
```

1. Instala o `dnsmasq` via `apk` (gerenciador do Alpine)
2. Inicia o `dnsmasq` em modo foreground (`--no-daemon`) para que o Docker monitore o processo
3. Lê as configurações de `/etc/dnsmasq.conf` — que é o arquivo `config/dnsmasq.conf` montado via volume

### Arquivo de configuração — `config/dnsmasq.conf`

```ini
# Desabilita DNS puro (evita conflito com o roteador)
port=0

# Interface física onde o PowerBook G4 está conectado
interface=enp62s0u1u2

# Faixa de IPs oferecidos ao PowerBook via DHCP
dhcp-range=192.168.1.200,192.168.1.220,255.255.255.0,1h

# Gateway padrão enviado ao PowerBook (IP do Dell Precision na LAN)
dhcp-option=3,192.168.1.1

# DNS enviado ao PowerBook (Google — evita falhas de resolução)
dhcp-option=6,8.8.8.8

# Arquivo de boot servido via TFTP ao OpenFirmware do PowerBook
dhcp-boot=vmlinuz

# Ativa o servidor TFTP interno do dnsmasq
enable-tftp

# Diretório raiz do TFTP (dentro do container)
tftp-root=/var/lib/tftpboot

# Logs detalhados para diagnóstico
log-dhcp
log-queries
```

### Verificar se está funcionando

```bash
# Ver se o container está rodando
docker ps | grep powerg4-pxe-tftp

# Ver logs em tempo real
docker logs -f powerg4-pxe-tftp

# Quando o PowerBook tentar conectar, aparecerá algo como:
# dnsmasq-dhcp: DHCPDISCOVER(enp62s0u1u2) aa:bb:cc:dd:ee:ff
# dnsmasq-dhcp: DHCPOFFER(enp62s0u1u2) 192.168.1.200 aa:bb:cc:dd:ee:ff
# dnsmasq-tftp: sent /var/lib/tftpboot/vmlinuz to 192.168.1.200
```

---

## 🌐 Container 2 — `powerg4-web-server`

### Função

Servidor HTTP leve que entrega três arquivos ao instalador Debian em execução no PowerBook G4:

| Arquivo | URL | Função |
|---|---|---|
| `preseed.cfg` | `http://192.168.1.1/preseed.cfg` | Respostas automáticas do instalador |
| `vmlinuz` | `http://192.168.1.1/debian-powerpc/vmlinuz` | Kernel (backup via HTTP) |
| `initrd.gz` | `http://192.168.1.1/debian-powerpc/initrd.gz` | Ramdisk (backup via HTTP) |

### Imagem base

```
nginx:alpine
```

O `nginx:alpine` combina o servidor web mais performático do mercado com a base Alpine, resultando em uma imagem de **~23MB** com zero configuração adicional necessária.

### Por que HTTP além do TFTP?

O TFTP serve os arquivos no **primeiro estágio** do boot (OpenFirmware → kernel). Após o kernel iniciar, o instalador Debian busca o `preseed.cfg` via **HTTP** — um protocolo mais confiável para transferências maiores e com suporte a autenticação de conteúdo.

### Verificar se está funcionando

```bash
# Ver se o container está rodando
docker ps | grep powerg4-web-server

# Testar resposta HTTP diretamente do Dell Precision
curl -sL -o /dev/null -w "HTTP %{http_code}\n" http://localhost/preseed.cfg
# deve retornar: HTTP 200

curl -sL -o /dev/null -w "HTTP %{http_code}\n" http://localhost/debian-powerpc/vmlinuz
# deve retornar: HTTP 200

# Ver logs de acesso em tempo real
docker logs -f powerg4-web-server
# quando o PowerBook acessar, aparecerá:
# 192.168.1.200 - - [20/Jun/2026:10:15:32 +0000] "GET /preseed.cfg HTTP/1.1" 200 4821
```

---

## 📄 `docker-compose.yml` explicado

```yaml
# Compose V2 — linha 'version' omitida (obsoleta no Docker moderno)

services:

  # ─────────────────────────────────────────────
  # Container 1: DHCP + TFTP
  # ─────────────────────────────────────────────
  pxe-tftp:
    image: alpine:latest
    container_name: powerg4-pxe-tftp
    restart: unless-stopped          # reinicia automaticamente se cair

    # NET_ADMIN é obrigatório para o dnsmasq
    # operar como servidor DHCP na rede física
    cap_add:
      - NET_ADMIN

    # host = sem NAT interno do Docker
    # container usa diretamente as interfaces do Dell Precision
    # obrigatório para DHCP funcionar na rede local real
    network_mode: "host"

    volumes:
      # Configuração do dnsmasq (read-only — container não pode alterar)
      - ./config/dnsmasq.conf:/etc/dnsmasq.conf:ro
      # Arquivos de boot servidos via TFTP
      - ./www/debian-powerpc:/var/lib/tftpboot:ro

    # Instala dnsmasq e inicia em foreground
    command: >
      sh -c 'apk add --no-cache dnsmasq &&
             dnsmasq --no-daemon --conf-file=/etc/dnsmasq.conf'

  # ─────────────────────────────────────────────
  # Container 2: Servidor HTTP
  # ─────────────────────────────────────────────
  web-server:
    image: nginx:alpine
    container_name: powerg4-web-server
    restart: unless-stopped

    # host = porta 80 diretamente no Dell Precision
    # PowerBook acessa http://192.168.1.1/ sem redirecionamento
    network_mode: "host"

    volumes:
      # Todo o conteúdo de ./www é servido como raiz HTTP
      - ./www:/usr/share/nginx/html:ro
```

### Por que `network_mode: host`?

| Modo | Como funciona | Por que não serve aqui |
|---|---|---|
| `bridge` (padrão) | Docker cria rede virtual isolada | DHCP broadcast não atravessa NAT do Docker |
| `host` | Container usa rede do host diretamente | ✅ DHCP e TFTP funcionam na rede física real |

---

## 📂 Volumes compartilhados

```
Host (Dell Precision)          Container
─────────────────────────────────────────────────────
./config/dnsmasq.conf    →    /etc/dnsmasq.conf          (pxe-tftp, ro)
./www/debian-powerpc/    →    /var/lib/tftpboot/          (pxe-tftp, ro)
./www/                   →    /usr/share/nginx/html/      (web-server, ro)
```

Ambos os containers montam os volumes como **read-only (`:ro`)** — os arquivos só podem ser modificados no host, nunca de dentro dos containers.

---

## 🛠️ Comandos do dia a dia

### Subir os containers

```bash
docker compose up -d
```

### Ver status

```bash
docker compose ps
# ou com mais detalhes:
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
```

Saída esperada:
```
NAMES                  STATUS          IMAGE
powerg4-web-server     Up 5 hours      nginx:alpine
powerg4-pxe-tftp       Up 5 hours      alpine:latest
```

### Ver logs

```bash
# Todos os containers juntos
docker compose logs -f

# Apenas DHCP/TFTP
docker logs -f powerg4-pxe-tftp

# Apenas HTTP
docker logs -f powerg4-web-server

# Últimas 50 linhas
docker logs --tail 50 powerg4-pxe-tftp
```

### Reiniciar um container específico

```bash
docker compose restart pxe-tftp
docker compose restart web-server
```

### Derrubar tudo

```bash
docker compose down
```

### Entrar dentro de um container para depuração

```bash
# Entrar no container Alpine (DHCP/TFTP)
docker exec -it powerg4-pxe-tftp sh

# Entrar no container nginx
docker exec -it powerg4-web-server sh

# Dentro do container nginx — verificar arquivos servidos
ls /usr/share/nginx/html/
ls /usr/share/nginx/html/debian-powerpc/
```

### Recriar containers do zero (após mudança no compose)

```bash
docker compose down
docker compose up -d --force-recreate
```

---

## 🔍 Diagnóstico e logs

### Verificar se o PowerBook recebeu IP

```bash
# Ver concessões DHCP ativas
docker exec powerg4-pxe-tftp cat /var/lib/misc/dnsmasq.leases
# formato: timestamp  mac  ip  hostname  clientid
```

### Verificar transferências TFTP

```bash
docker logs powerg4-pxe-tftp | grep -i tftp
# deve aparecer:
# dnsmasq-tftp: sent /var/lib/tftpboot/vmlinuz to 192.168.1.200
# dnsmasq-tftp: sent /var/lib/tftpboot/initrd.gz to 192.168.1.200
```

### Verificar acesso ao preseed

```bash
docker logs powerg4-web-server | grep preseed
# deve aparecer:
# 192.168.1.200 - - [...] "GET /preseed.cfg HTTP/1.1" 200 4821
```

### Verificar uso de recursos

```bash
docker stats powerg4-pxe-tftp powerg4-web-server
```

Valores normais em idle:

| Container | CPU | RAM |
|---|---|---|
| `powerg4-pxe-tftp` | < 0.1% | ~8 MB |
| `powerg4-web-server` | < 0.1% | ~6 MB |

---

## 🔧 Resolução de problemas

### Container `powerg4-pxe-tftp` não inicia

```bash
docker logs powerg4-pxe-tftp
```

Causa mais comum — porta 67 já em uso (outro DHCP rodando):
```bash
sudo ss -ulnp | grep :67
# se aparecer algo, pare o serviço conflitante:
sudo systemctl stop isc-dhcp-server
sudo systemctl stop dnsmasq   # se dnsmasq já estiver rodando no host
```

### PowerBook recebe IP mas não baixa vmlinuz

```bash
# Verificar se os arquivos existem no volume
ls -lh www/debian-powerpc/
# deve mostrar vmlinuz e initrd.gz com tamanho > 0

# Verificar permissões
chmod 644 www/debian-powerpc/vmlinuz www/debian-powerpc/initrd.gz
```

### nginx retorna 403 Forbidden

```bash
# Verificar permissões da pasta www
chmod -R 755 www/
chmod 644 www/preseed.cfg
```

### Conflito de porta 80 no host

```bash
# Ver o que está usando a porta 80
sudo ss -tlnp | grep :80
# parar o serviço conflitante, por exemplo:
sudo systemctl stop apache2
```

### Recriar o container do zero após corrigir problema

```bash
docker compose down
docker compose up -d --force-recreate --build
docker compose logs -f
```
