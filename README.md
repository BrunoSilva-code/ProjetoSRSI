# Laboratório Kali em Docker

Laboratório local com dois contentores Kali na rede Docker `mitm-lab`.

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

## Teste de ARP Spoofing

No terminal do Kali atacante, inicia o Ettercap:

```bash
sudo -n /usr/bin/ettercap -T -o -i eth0 -M arp:remote /172.19.0.3// /172.19.0.1//
```

No Wireshark do atacante, captura em `eth0`. Para filtrar o tráfego da vítima, usa:

```text
ip.addr == 172.19.0.3
```

Gera tráfego no browser do Kali vítima. Para terminar o Ettercap, carrega em **Ctrl+C** no terminal onde está a correr.

## Notas

- A porta VNC está ligada a `127.0.0.1` e não tem password; usa-a apenas localmente.
- Os IPs estão fixos na configuração da rede `172.19.0.0/24`. Se essa sub-rede já estiver em uso no computador, altera-a no `compose.yaml`.
