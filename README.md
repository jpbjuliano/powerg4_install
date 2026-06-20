# 🍏 Projeto PowerBook G4: Automatização de Deploy via Rede (PXE/TFTP)

Este repositório contém a infraestrutura e a documentação metodológica para o provisionamento e a instalação automatizada do sistema operacional Debian Ports (arquitetura PowerPC 32-bits) em um laptop legado **Apple PowerBook G4**, utilizando um ambiente conteinerizado no Docker a partir de uma estação de trabalho moderna (Dell Precision 5510).

---

## 📖 1. História e Motivação

### A Era de Ouro do PowerPC
No início dos anos 2000, a arquitetura RISC PowerPC (desenvolvida pela aliança AIM: Apple, IBM e Motorola) representava o topo do desempenho computacional, superando os processadores x86 da época em processamento por ciclo de clock. O PowerBook G4 de alumínio foi um marco da engenharia, unindo design industrial sofisticado e alta capacidade de processamento. Contudo, em 2006, a Apple migrou para a arquitetura Intel, deixando essa geração histórica de hardware relegada ao esquecimento de software proprietário estagnado no Mac OS X 10.5 (Leopard).

### A Era de Ouro do PowerPC e o Legado Alumínio de 17"
No início dos anos 2000, a arquitetura RISC PowerPC (desenvolvida pela aliança AIM: Apple, IBM e Motorola) representava o topo do desempenho computacional. Em janeiro de 2003, a Apple revolucionou o mercado de portáteis ao introduzir a linha baseada em alumínio aeronáutico, destacando-se o imponente **PowerBook G4 de 17 polegadas** (resoluções de 1440x900 a 1680x1050 de alta densidade). 

Promovido na época como o primeiro notebook de 17 polegadas do mundo, ele trazia inovações revolucionárias para a engenharia de hardware, como teclado retroiluminado por sensores de luz ambiente, portas FireWire 800 e conectividade sem fio AirPort Extreme embutida. Contudo, em 2006, a transição para processadores Intel encerrou essa linhagem, deixando esse gigante de engenharia estagnado no antigo Mac OS X 10.5 (Leopard).

### A Motivação da Restauração
Restaurar este PowerBook G4 Alumínio de 17" em pleno ano de 2026 vai muito além da nostalgia; é um manifesto de **preservação digital, soberania tecnológica e sustentabilidade (Green IT)**:
* **Preservação de Hardware Histórico:** Manter operacional uma estação de trabalho que foi um marco de engenharia móvel, evitando o descarte de uma carcaça de alumínio intacta e uma tela profissional de grandes proporções.
* **Superação de Gargalos de Hardware Legado:** Contornar a degradação física de drives ópticos (SuperDrive) e o suporte complexo de boot por USB através do barramento OpenFirmware.
* **Habilitação de Gráficos e Periféricos Dedicados:** A arquitetura de 17 polegadas carrega chips gráficos potentes para a época (como as famílias NVIDIA GeForce4 Go / FX Go5200 ou ATI Mobility Radeon 9600/9700). Trazer o ecossistema moderno do Debian MATE exige a correta injeção de firmwares proprietários (`non-free-firmware`) mapeados via rede, permitindo que a GPU seja reativada com aceleração nativa e sem travamentos.


### A Motivação da Restauração
### Restaurar um PowerBook G4 em pleno ano de 2026 vai muito além da nostalgia; é um manifesto de ### **preservação digital, soberania tecnológica e sustentabilidade (Green IT)**. 
### * **Preservação de Hardware:** Evitar que máquinas com engenharia excepcional virem lixo eletrônico.
### * **Desafio de Engenharia:** Superar as barreiras de um ecossistema cujo suporte oficial foi descontinuado há quase duas décadas.
### * **Segurança e Atualidade:** Trazer o hardware de volta à vida com um Kernel Linux moderno, permitindo o uso prático de ferramentas de rede, terminal e a interface gráfica MATE estável.

---

## 🎯 2. O Problema Técnico

Instalar um Linux moderno em um Mac NewWorld (arquitetura OpenFirmware) apresenta desafios críticos:
1. **Mídias Físicas Inviáveis:** Leitores de DVD/CD originais desses notebooks costumam estar degradados ou falhar na leitura de mídias gravadas modernas.
2. **Incompatibilidade de Boot USB:** O OpenFirmware dos Macs G4 possui suporte nativo instável e complexo para boot via pendrives USB, frequentemente resultando em falhas de leitura de blocos.
3. **Isolamento de Repositórios:** Como a arquitetura PowerPC (32-bits) foi movida para o repositório de portes instáveis (`unstable/sid`), os espelhos de pacotes padrão do Debian falham. O instalador precisa ser instruído estritamente a buscar árvores congeladas (*snapshots*) específicas e a injetar firmwares proprietários (`non-free`) para que o hardware de vídeo (ATI/NVIDIA) e rede sem fio funcionem.

---

## 🛠️ 3. O Método e Processos Empregados

A solução aplicada mitigou as falhas físicas de hardware eliminando mídias locais e isolando o ambiente de instalação em uma rede local fechada via cabo, controlada por containers Docker no host (Dell Precision 5510).

### Arquitetura de Conexão Física e NAT
A estação de trabalho moderna atua como o servidor de infraestrutura e roteador de borda para o Mac antigo:



### Processos do Servidor (Host Precision 5510)
* **Docker Compose:** Orquestra dois serviços essenciais:
  * **Alpine (dnsmasq):** Atua de forma combinada como servidor DHCP (fornecendo IPs na sub-rede `192.168.1.0/24`) e servidor TFTP (enviando os arquivos essenciais de boot `vmlinux` e `initrd.gz`).
  * **Nginx:** Servidor Web leve responsável por hospedar e servir o arquivo de automação de respostas `preseed.cfg`.
* **Roteamento de Kernel (IPTables/NAT):** Configuração de mascaramento de pacotes para capturar o tráfego da rede cabeada (`enp62s0u1u2`) e roteá-lo através da interface Wi-Fi (`wlp2s0`) ativa com a internet, garantindo que o instalador do Mac consiga baixar pacotes externos.

### Processos do Cliente (PowerBook G4)
* **OpenFirmware Console:** Interceptação do hardware em baixo nível através do atalho `Cmd + Option + O + F`.
* **Injeção de Preseed Estático:** Execução do comando de boot instruindo a placa de rede embutida (`enet`) a buscar as instruções HTTP e fixar parâmetros de sub-rede e DNS (`8.8.8.8`) para contornar falhas de resolução de nomes.

---

## 📊 4. Fluxograma do Processo de Deploy

O ciclo de vida completo da automação, desde a inicialização do ambiente até a conclusão da instalação, segue o fluxo padronizado abaixo:



```text
[ Estação Precision 5510 ]                    [ PowerBook G4 ]
          |                                          |
          +---> Inicializa Containers Docker         |
          |     (dnsmasq e Nginx Ativos)             |
          |                                          |
          |     Ativa Roteamento IP e NAT            |
          |     (wlp2s0 <---> enp62s0u1u2)            |
          |                                          |
          |                                          +---> Boot no OpenFirmware (Cmd+Opt+O+F)
          |                                          |
          |                                          +---> Comando: boot enet:0,preseed/url=...
          |                                          |
          |<--- Requisição DHCP Broadcast <----------+
          |                                          |
          +---> Envia IP e Arquivos via TFTP ------->|
          |     (vmlinux / initrd.gz)                |
          |                                          |
          |<--- Requisição HTTP (preseed.cfg) <------+
          |                                          |
          +---> Entrega arquivo via Nginx (200 OK) ->|
          |                                          |
          |<--- Tráfego de Pacotes (Debian Ports) <--+ (Instalação Automatizada)
          |     [Roteado via NAT para a Internet]    |
          |                                          |
          |                                          +---> Finalização: Sistema MATE Pronto!