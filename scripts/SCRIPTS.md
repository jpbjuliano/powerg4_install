# 📜 Manual dos Scripts — PowerBook G4 Deploy

> Documentação completa de cada script do projeto, onde colocar, quando executar e como funciona internamente.

---

## 📁 Onde colocar os scripts no projeto

```text
powerg4_install/                  ← raiz do repositório
├── docker-compose.yml
├── .env
├── .env.example
├── .gitignore
├── README.md
├── SCRIPTS.md                    ← este manual
│
├── config/
│   └── dnsmasq.conf
│
├── www/
│   ├── preseed.cfg
│   └── debian-powerpc/
│       ├── vmlinuz               ← gerado por download-boot-files.sh
│       └── initrd.gz             ← gerado por download-boot-files.sh
│
└── scripts/                      ← ⬅ PASTA DOS SCRIPTS
    ├── check.sh                  ← validação do ambiente
    ├── download-boot-files.sh    ← baixa kernel e ramdisk
    └── setup-nat.sh              ← ativa roteamento e NAT
```

---

## ⚡ Ordem de execução obrigatória

Execute **sempre nessa ordem** antes de cada sessão de deploy:

```
1. download-boot-files.sh   →  baixa os arquivos de boot (só na primeira vez)
2. check.sh                 →  valida que tudo está no lugar
3. setup-nat.sh             →  ativa o roteamento de rede
4. docker compose up -d     →  sobe os containers
```

---

## 📋 Preparação inicial (uma única vez)

Após clonar o repositório, torne os scripts executáveis:

```bash
cd ~/Documentos/automacao/powerg4_install
chmod +x scripts/check.sh
chmod +x scripts/download-boot-files.sh
chmod +x scripts/setup-nat.sh
```

Verifique:
```bash
ls -lh scripts/
# deve aparecer -rwxr-xr-x para cada arquivo
```

---

## 🔽 Script 1 — `download-boot-files.sh`

### O que faz

Baixa os dois arquivos essenciais para o boot do instalador Debian no PowerBook G4:

| Arquivo | Função |
|---|---|
| `vmlinuz` | Kernel Linux de instalação (PowerPC 32-bit) |
| `initrd.gz` | Sistema de arquivos em RAM com o instalador Debian |

Ambos são servidos via TFTP para o PowerBook G4 durante o boot de rede.

### Quando executar

- **Primeira vez** após clonar o repositório
- Quando quiser **atualizar** para uma versão mais recente do instalador
- Se os arquivos forem deletados acidentalmente

### Como executar

```bash
cd ~/Documentos/automacao/powerg4_install
./scripts/download-boot-files.sh
```

### Saída esperada

```
🔽 Baixando arquivos de boot do Debian Ports (PowerPC)...
vmlinuz        [===================>] 4,2MB  1,1MB/s   em 3,8s
initrd.gz      [===================>] 22MB   1,3MB/s   em 17s
✅ Download concluído:
-rw-r--r-- 1 j j 4,2M jun 20 10:15 www/debian-powerpc/vmlinuz
-rw-r--r-- 1 j j  22M jun 20 10:15 www/debian-powerpc/initrd.gz
```

### Mirror utilizado

O script usa o **único mirror confirmado como HTTP 200** para PowerPC:

```
http://ftp.ports.debian.org/debian-ports
```

Caminho completo dos arquivos:
```
.../dists/sid/main/installer-powerpc/current/images/netboot/vmlinuz
.../dists/sid/main/installer-powerpc/current/images/netboot/initrd.gz
```

### Testar mirror manualmente antes de baixar

```bash
curl -sL -o /dev/null -w "HTTP %{http_code}\n" \
  "http://ftp.ports.debian.org/debian-ports/dists/sid/InRelease"
# deve retornar: HTTP 200
```

### Erros comuns

| Erro | Causa | Solução |
|---|---|---|
| `404 Not Found` | Caminho do instalador mudou no mirror | Verifique `ftp.ports.debian.org/debian-ports/dists/sid/main/` manualmente |
| `Connection refused` | Sem internet ou mirror fora do ar | Tente o mirror alternativo `snapshot.debian.org` |
| Arquivo vazio (0 bytes) | Download interrompido | Delete o arquivo e rode o script novamente |

---

## ✅ Script 2 — `check.sh`

### O que faz

Valida **todos os pré-requisitos** do ambiente antes de iniciar o deploy. Verifica:

1. Presença dos arquivos de boot (`vmlinuz`, `initrd.gz`)
2. Presença do arquivo de automação (`preseed.cfg`)
3. Se o Docker está rodando
4. Se o mirror Debian Ports responde (HTTP 200)
5. Se o IP forwarding está ativo no kernel

### Quando executar

- **Sempre** antes de subir os containers
- Após qualquer mudança de configuração de rede
- Para diagnosticar por que o deploy não está funcionando

### Como executar

```bash
cd ~/Documentos/automacao/powerg4_install
./scripts/check.sh
```

### Saída esperada (tudo OK)

```
═══════════════════════════════════════
  PowerBook G4 — Validação de Ambiente
═══════════════════════════════════════
✅ vmlinuz encontrado
✅ initrd.gz encontrado
✅ preseed.cfg encontrado
✅ Docker está rodando
✅ Mirror ftp.ports.debian.org respondendo (HTTP 200)
✅ IP forwarding ativo
═══════════════════════════════════════
✅ Ambiente pronto para deploy!
   Execute: docker compose up -d
═══════════════════════════════════════
```

### Saída com problemas

```
═══════════════════════════════════════
  PowerBook G4 — Validação de Ambiente
═══════════════════════════════════════
❌ vmlinuz ausente — rode ./scripts/download-boot-files.sh
✅ initrd.gz encontrado
✅ preseed.cfg encontrado
✅ Docker está rodando
✅ Mirror ftp.ports.debian.org respondendo (HTTP 200)
⚠️  IP forwarding inativo — rode sudo ./scripts/setup-nat.sh
═══════════════════════════════════════
❌ 2 problema(s) encontrado(s) — corrija antes de continuar.
═══════════════════════════════════════
```

### Significado dos símbolos

| Símbolo | Significado | Ação necessária |
|---|---|---|
| ✅ | OK — pode continuar | Nenhuma |
| ❌ | Erro crítico — deploy não funcionará | Corrigir antes de prosseguir |
| ⚠️ | Aviso — pode funcionar parcialmente | Corrigir recomendado |

---

## 🌐 Script 3 — `setup-nat.sh`

### O que faz

Configura o **Dell Precision 5510 como roteador NAT** entre:

- `LAN_INTERFACE` (ex: `enp62s0u1u2`) — cabo Ethernet conectado ao PowerBook G4
- `WAN_INTERFACE` (ex: `wlp2s0`) — Wi-Fi com acesso à internet

Sem esse script, o PowerBook G4 recebe IP e os arquivos de boot via TFTP, mas **não consegue baixar pacotes Debian da internet** durante a instalação.

### Quando executar

- Antes de cada sessão de deploy (as regras do iptables são perdidas após reboot)
- Sempre **após** o `check.sh` e **antes** do `docker compose up`
- Requer `sudo` — altera regras de firewall do sistema

### Como executar

```bash
cd ~/Documentos/automacao/powerg4_install
sudo ./scripts/setup-nat.sh
```

> ⚠️ **Requer sudo** — o script altera regras de iptables e o IP forwarding do kernel.

### Saída esperada

```
🔧 Ativando IP forwarding...
🔧 Configurando NAT (enp62s0u1u2 ↔ wlp2s0)...
✅ NAT ativo. PowerBook G4 pode acessar a internet via wlp2s0
default via 192.168.0.1 dev wlp2s0 proto dhcp
192.168.0.0/24 dev wlp2s0 proto kernel
192.168.1.0/24 dev enp62s0u1u2 proto kernel
```

### O que o script faz internamente

```bash
# 1. Habilita roteamento de pacotes entre interfaces
echo 1 > /proc/sys/net/ipv4/ip_forward

# 2. Mascara o IP do PowerBook ao sair pela Wi-Fi (NAT)
iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE

# 3. Permite tráfego do PowerBook → internet
iptables -A FORWARD -i enp62s0u1u2 -o wlp2s0 -j ACCEPT

# 4. Permite respostas da internet → PowerBook
iptables -A FORWARD -i wlp2s0 -o enp62s0u1u2 \
  -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Verificar se o NAT está ativo

```bash
# Verificar IP forwarding
cat /proc/sys/net/ipv4/ip_forward
# deve retornar: 1

# Verificar regras NAT
sudo iptables -t nat -L POSTROUTING -n -v
# deve mostrar a regra MASQUERADE em wlp2s0

# Verificar regras FORWARD
sudo iptables -L FORWARD -n -v
# deve mostrar as regras de enp62s0u1u2 e wlp2s0
```

### Descobrir os nomes das suas interfaces

```bash
ip link show
# ou
nmcli device status
```

Procure:
- A interface **Ethernet** conectada ao PowerBook (geralmente `enp*` ou `eth*`)
- A interface **Wi-Fi** com internet (geralmente `wlp*` ou `wlan*`)

Depois edite o `.env`:
```env
LAN_INTERFACE=enp62s0u1u2   # sua interface Ethernet
WAN_INTERFACE=wlp2s0        # sua interface Wi-Fi
```

### Tornar o NAT permanente (opcional)

Por padrão, as regras são perdidas após reboot. Para tornar permanente:

```bash
sudo apt install iptables-persistent -y
sudo netfilter-persistent save
```

E para o IP forwarding persistir, edite `/etc/sysctl.conf`:
```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Erros comuns

| Erro | Causa | Solução |
|---|---|---|
| `Permission denied` | Script executado sem sudo | Use `sudo ./scripts/setup-nat.sh` |
| `.env não encontrado` | Arquivo `.env` ausente na raiz | Copie de `.env.example` e ajuste |
| PowerBook acessa LAN mas não a internet | Interface errada no `.env` | Verifique com `ip link show` e corrija `WAN_INTERFACE` |
| Regras duplicadas após reexecutar | Script adicionou regras novamente | Limpe com `sudo iptables -F && sudo iptables -t nat -F` e reexecute |

---

## 🔄 Sessão completa de deploy — sequência ideal

```bash
# Entrar na pasta do projeto
cd ~/Documentos/automacao/powerg4_install

# 1. Baixar arquivos de boot (só na primeira vez ou para atualizar)
./scripts/download-boot-files.sh

# 2. Validar ambiente
./scripts/check.sh

# 3. Ativar NAT
sudo ./scripts/setup-nat.sh

# 4. Subir containers
docker compose up -d

# 5. Acompanhar logs em tempo real
docker compose logs -f

# --- No PowerBook G4 ---
# Pressionar Cmd+Option+O+F ao ligar
# No prompt do OpenFirmware:
# boot enet:0,yaboot

# 6. Ao terminar, derrubar containers
docker compose down

# 7. Remover NAT (opcional — some sozinho no reboot)
sudo iptables -F
sudo iptables -t nat -F
echo 0 > /proc/sys/net/ipv4/ip_forward
```

---

## 🆘 Diagnóstico rápido

Se algo não funcionar, rode esse bloco completo para coletar informações:

```bash
echo "=== Arquivos de boot ===" && ls -lh www/debian-powerpc/
echo "=== Docker ===" && docker compose ps
echo "=== IP forwarding ===" && cat /proc/sys/net/ipv4/ip_forward
echo "=== Regras NAT ===" && sudo iptables -t nat -L -n
echo "=== Mirror ===" && curl -sL -o /dev/null -w "HTTP %{http_code}\n" \
  "http://ftp.ports.debian.org/debian-ports/dists/sid/InRelease"
echo "=== Interfaces ===" && ip addr show
echo "=== Logs dnsmasq ===" && docker compose logs powerg4-pxe-tftp | tail -20
```

Cole a saída em uma issue do repositório para facilitar o diagnóstico.
