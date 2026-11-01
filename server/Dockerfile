FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    mariadb-server \
    mariadb-client \
    python3-scapy \
    nftables \
    iproute2 \
    iputils-ping \
    && apt clean

# Aceitar ligacoes de outras maquinas (Cliente), nao so de 127.0.0.1
RUN mkdir -p /etc/mysql/mariadb.conf.d \
    && printf '[mysqld]\nbind-address = 0.0.0.0\n' \
       > /etc/mysql/mariadb.conf.d/99-lab.cnf

COPY init.sql /root/init.sql
COPY detetor_arp.py /root/detetor_arp.py
COPY server-start.sh /server-start.sh
RUN chmod +x /server-start.sh

EXPOSE 3306

CMD ["/server-start.sh"]
