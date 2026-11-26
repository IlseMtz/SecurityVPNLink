#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
[[ $(id -un) == Nero ]] || { echo 'Ejecuta como Nero, sin sudo.' >&2; exit 1; }
backend=/home/Nero/securelink-azure/backend
api=$backend/src/main/java/mx/securelink/backend/api
agent=/usr/local/lib/securelink-agent
container=securelink-azure-mysql-1
tmp=$(mktemp -d)
trap 'rm -f -- "$tmp/agent.py"; rmdir -- "$tmp"' EXIT

test -f "$api/ManagementSupport.java"
test -f "$api/WireGuardClient.java"
grep -q SECURELINK_GESTION_ENDPOINTS "$api/ApiSecurity.java"
sudo systemctl is-active --quiet securelink-vpn-firewall
sudo /usr/sbin/iptables -w -C FORWARD -j DOCKER-USER
sudo test -x /usr/sbin/ipset
sudo ip -4 route show exact 172.30.77.0/24 | grep -q 'dev br-sl-lab'
sudo python3 prepare_install.py "$agent/agent.py" "$tmp/agent.py"

backup=$(sudo mktemp -d /root/securelink-vs17-XXXXXXXX)
echo "Respaldo: $backup"
sudo cp -a "$agent/agent.py" "$api" "$backend/target/securelink-backend-0.0.1-SNAPSHOT.jar" "$backup/"
sudo sh -c 'umask 077; docker exec "$1" sh -c '\''MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" exec mysqldump --single-transaction --no-tablespaces -u root securelink'\'' > "$2/mysql.sql"' sh "$container" "$backup"

# Prepare and compile the new sources before restarting either service.
install -m 644 ResourceController.java ResourceSync.java "$api/"
(cd "$backend" && mvn -DskipTests package)
sudo docker exec -i "$container" sh -c 'MYSQL_PWD="$(cat /run/secrets/mysql_root_password)" exec mysql -u root securelink' < V7__recursos.sql

sudo install -m 644 agent_resources.py "$agent/agent_resources.py"
sudo install -m 755 firewall.sh "$agent/resource-firewall.sh"
sudo install -m 644 securelink-resource-firewall.service /etc/systemd/system/securelink-resource-firewall.service
sudo install -d /etc/systemd/system/securelink-agent.service.d
printf '[Unit]\nRequires=securelink-resource-firewall.service\nAfter=securelink-resource-firewall.service\n' | \
  sudo tee /etc/systemd/system/securelink-agent.service.d/vs17-resources.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl start securelink-resource-firewall
sudo install -m 644 "$tmp/agent.py" "$agent/agent.py"
sudo systemctl restart securelink-agent
sudo systemctl is-active --quiet securelink-agent
sudo systemctl restart securelink-backend
sudo systemctl is-active --quiet securelink-backend
echo 'Instalación aplicada. Ejecuta la aceptación de VS-17 con equipos de prueba.'
