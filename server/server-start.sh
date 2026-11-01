#!/bin/bash
set -e

DATADIR=/var/lib/mysql

# Inicializar a base de dados na primeira vez (volume vazio)
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[*] A inicializar a base de dados MariaDB..."
  mariadb-install-db --user=mysql --datadir="$DATADIR" \
    --auth-root-authentication-method=normal >/dev/null 2>&1
fi
chown -R mysql:mysql "$DATADIR"

# Arrancar o servidor em segundo plano para carregar o schema
echo "[*] A arrancar o MySQL/MariaDB..."
mysqld_safe --datadir="$DATADIR" &

# Esperar que o servidor aceite ligacoes
for i in $(seq 1 30); do
  if mysqladmin ping --silent 2>/dev/null; then
    break
  fi
  sleep 1
done

# Carregar o schema 'loja' apenas uma vez
if [ ! -f "$DATADIR/.seeded" ]; then
  echo "[*] A carregar o schema 'loja'..."
  mysql < /root/init.sql
  touch "$DATADIR/.seeded"
fi

echo
echo "============================================================"
echo "[*] Servidor MySQL pronto em 0.0.0.0:3306  (IP 172.19.0.4)"
echo "[*] BD: loja  | utilizador: app  | password: senha123"
echo "[*] Para iniciar o detetor de ARP spoofing, corre aqui:"
echo "        python3 /root/detetor_arp.py"
echo "============================================================"
echo

# Manter o container vivo seguindo o processo do MySQL
wait
