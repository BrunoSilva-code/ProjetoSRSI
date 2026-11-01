# Laboratório Kali em Docker

Laboratório local com três contentores na rede Docker `mitm-lab`:

| Papel | Contentor | Imagem | IP |
|-------|-----------|--------|----|
| Atacante (Kali, GUI) | `kali-attacker` | `mitm-lab-kali` | 172.19.0.2 |
| Cliente / Vítima (Kali, GUI) | `kali-victim` | `mitm-lab-kali` | 172.19.0.3 |
| Servidor MySQL + detetor | `mysql-server` | `mitm-lab-server` | 172.19.0.4 |

> A interface de rede dentro dos contentores chama-se **`eth0`** (ao contrário das
> VMs do VMware, onde seria `ens34`/`eth1`).

## Requisitos

- Docker Desktop com contentores Linux
- Docker Compose v2

## Iniciar

Depois de clonar o repositório, abre um terminal na pasta do projeto e executa:

```powershell
docker compose up -d --build
```

Abre as interfaces gráficas no browser:

- Atacante: <http://localhost:6080/vnc.html> — `172.19.0.2`
- Vítima: <http://localhost:6081/vnc.html> — `172.19.0.3`
- Gateway da rede Docker: `172.19.0.1`

Para parar os contentores:

```powershell
docker compose down
```

## Demonstração completa: MitM a uma ligação SQL

O cenário é: o **Cliente** (vítima, `172.19.0.3`) liga-se à base de dados no
**Servidor** (`172.19.0.4`); o **Atacante** (`172.19.0.2`) coloca-se no meio por ARP
spoofing e lê o tráfego SQL em claro. O **detetor** corre no Servidor e reage.

### 1. Ligação normal Cliente → Servidor

No terminal do Kali **vítima** (faz de cliente), liga-te à BD. Usa `--skip-ssl`
para simular a aplicação mal configurada (sem cifra) — é o que torna o tráfego
legível para o atacante. Sem esta opção, o MariaDB negoceia TLS e o atacante só
vê dados cifrados.

```bash
mariadb --skip-ssl -h 172.19.0.4 -u app -psenha123 loja      # password: senha123
```

```sql
SELECT * FROM clientes;     -- mostra a Ana (100.00) e o Bruno (250.00)
EXIT;
```

### 2. Ataque (no Kali atacante)

Inicia o Ettercap a envenenar o Cliente **e** o Servidor:

```bash
sudo -n /usr/bin/ettercap -T -o -i eth0 -M arp:remote /172.19.0.3// /172.19.0.4//
```

No Wireshark do atacante, captura em `eth0` com o filtro:

```text
mysql
```

> O filtro `mysql` só mostra conteúdo legível na ligação feita com `--skip-ssl`. Numa
> ligação normal (com TLS) o tráfego aparece como `tls` e não é legível — o que serve
> de prova da mitigação. Para isolar apenas a vítima podes usar `ip.addr == 172.19.0.3`.

### 3. Capturar o tráfego em claro

Com o ataque a correr, repete a query no Cliente. No Wireshark: botão direito num
pacote → **Follow → TCP Stream**. Vê-se a query `SELECT * FROM clientes` e os dados
em texto claro. (Alternativa sem GUI, no atacante: `sudo tcpdump -i eth0 -A 'tcp port 3306'`.)

### 4. Deteção e mitigação (no Servidor)

Entra no container do servidor e corre o detetor:

```powershell
docker exec -it mysql-server bash
```

```bash
python3 /root/detetor_arp.py
```

Quando o ataque arranca, o detetor aprende os MACs reais, deteta a troca de MAC,
bloqueia o MAC do atacante com `nftables` e repõe a entrada ARP correta. Confirma com:

```bash
nft list ruleset        # deve mostrar  ether saddr <MAC_do_atacante> drop
```

> **Nota sobre a cifra (importante):** a imagem usa MariaDB (compatível com o cliente
> `mysql`/`mariadb`). Por omissão o cliente **negoceia TLS**, logo o tráfego vai
> **cifrado** e o atacante, apesar de estar no meio, só vê dados ilegíveis. Por isso
> a demonstração do cenário vulnerável **obriga** a ligar com `--skip-ssl`, que
> desativa a cifra e simula uma aplicação mal configurada. O contrário — a ligação
> normal, com TLS — é já uma mitigação: o atacante não consegue ler o tráfego.

Para terminar o Ettercap, **Ctrl+C** no terminal onde está a correr.

## Notas

- A porta VNC está ligada a `127.0.0.1` e não tem password; usa-a apenas localmente.
- Os IPs estão fixos na configuração da rede `172.19.0.0/24`. Se essa sub-rede já estiver em uso no computador, altera-a no `compose.yaml`.
