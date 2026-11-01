#!/usr/bin/env python3
"""Detetor + mitigacao de ARP spoofing (corre no Servidor MySQL).

Escuta as respostas ARP da rede. Quando um IP que ja conhecia passa a
responder com um MAC diferente, assume que esta a ser alvo de ARP spoofing:
  1. avisa (deteccao);
  2. bloqueia o MAC do atacante com nftables e repoe a entrada ARP correta
     (mitigacao).

Em Docker a interface da rede do laboratorio chama-se sempre 'eth0'
(nas VMs do VMware seria ens34/eth1 -- aqui NAO).
"""
import subprocess
from datetime import datetime

from scapy.all import ARP, sniff

INTERFACE = "eth0"       # interface da rede do lab em Docker (confirmar com: ip a)
known_macs = {}          # IP -> MAC verdadeiro (o primeiro aprendido)
alerted = set()          # IPs ja tratados (nao repetir alerta/mitigacao)


def timestamp():
    return datetime.now().strftime("%H:%M:%S")


def run(cmd):
    subprocess.run(cmd, shell=True, capture_output=True, text=True)


def setup_firewall():
    run("nft add table inet filter")
    run("nft 'add chain inet filter input "
        "{ type filter hook input priority 0; policy accept; }'")


def block_attacker(mac):
    run(f"nft add rule inet filter input ether saddr {mac} drop")
    print(f"      -> MITIGACAO: regra nftables criada para BLOQUEAR o MAC {mac}")


def restore_arp(ip, real_mac):
    run(f"ip neigh replace {ip} lladdr {real_mac} dev {INTERFACE}")
    print(f"      -> MITIGACAO: ARP de {ip} reposto para o MAC verdadeiro {real_mac}")


def process_packet(pkt):
    if not (pkt.haslayer(ARP) and pkt[ARP].op == 2):   # 2 = resposta ARP ("is-at")
        return
    ip = pkt[ARP].psrc
    mac = pkt[ARP].hwsrc
    if ip not in known_macs:
        known_macs[ip] = mac
        print(f"[{timestamp()}] aprendi: {ip} = {mac}")
    elif known_macs[ip] != mac and ip not in alerted:
        real_mac = known_macs[ip]
        print(f"[{timestamp()}] *** ALERTA: possivel ARP SPOOFING ***")
        print(f"    O IP {ip} mudou de MAC:")
        print(f"      verdadeiro: {real_mac}")
        print(f"      atacante:   {mac}   <- suspeito")
        alerted.add(ip)
        block_attacker(mac)
        restore_arp(ip, real_mac)
        print()


if __name__ == "__main__":
    print(f"[*] A vigiar ARP em {INTERFACE}. Ctrl+C para parar.\n")
    setup_firewall()
    sniff(iface=INTERFACE, filter="arp", prn=process_packet, store=0)
