#!/usr/bin/env bash
# Instala el servidor de Memory Honduras y ngrok como servicios de systemd,
# para que se enciendan solos cada vez que arranca Rocky Linux (sin dejar
# ninguna terminal abierta).
#
# Uso (dentro de la carpeta "servidor"):
#   bash scripts/instalar_servicios.sh https://TU-DOMINIO.ngrok-free.dev
#
# Comandos útiles después:
#   systemctl status memory-honduras ngrok-memory   -> ver si están encendidos
#   sudo systemctl restart memory-honduras          -> reiniciar el servidor
#   journalctl -u memory-honduras -n 30             -> ver los últimos mensajes
set -euo pipefail

URL_NGROK="${1:-}"
if [[ -z "$URL_NGROK" ]]; then
  echo "Falta la dirección de ngrok. Ejemplo:"
  echo "  bash scripts/instalar_servicios.sh https://mi-dominio.ngrok-free.dev"
  exit 1
fi
[[ "$URL_NGROK" == https://* ]] || URL_NGROK="https://$URL_NGROK"
URL_NGROK="${URL_NGROK%/}"

USUARIO="$(id -un)"
CARPETA="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$(command -v node || true)"
NGROK="$(command -v ngrok || true)"

[[ -f "$CARPETA/server.js" ]] || { echo "No encuentro server.js en $CARPETA"; exit 1; }
[[ -f "$CARPETA/.env" ]]      || { echo "No encuentro el archivo .env en $CARPETA"; exit 1; }
[[ -n "$NODE" ]]  || { echo "No encuentro node. ¿Está instalado Node.js?"; exit 1; }
[[ -n "$NGROK" ]] || { echo "No encuentro ngrok. ¿Está instalado?"; exit 1; }

# SELinux no deja que systemd ejecute programas guardados en la carpeta
# personal. Si ngrok está ahí, se copia a /usr/local/bin.
if [[ "$NGROK" != /usr/* ]]; then
  echo "Copiando ngrok a /usr/local/bin ..."
  sudo cp "$NGROK" /usr/local/bin/ngrok
  sudo chmod 755 /usr/local/bin/ngrok
  sudo restorecon -v /usr/local/bin/ngrok >/dev/null 2>&1 || true
  NGROK=/usr/local/bin/ngrok
fi

echo "Usuario: $USUARIO"
echo "Carpeta: $CARPETA"
echo "node:    $NODE"
echo "ngrok:   $NGROK"
echo "Enlace:  $URL_NGROK"

# Se apagan las copias que se hayan encendido a mano con nohup.
pkill -u "$USUARIO" -f "node server.js" 2>/dev/null || true
pkill -u "$USUARIO" -x ngrok 2>/dev/null || true
sleep 1

sudo tee /etc/systemd/system/memory-honduras.service >/dev/null <<EOF
[Unit]
Description=Servidor de Memory Honduras (API + IA + PayPal)
After=network-online.target mysqld.service
Wants=network-online.target mysqld.service

[Service]
User=$USUARIO
WorkingDirectory=$CARPETA
ExecStart=$NODE server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/ngrok-memory.service >/dev/null <<EOF
[Unit]
Description=ngrok: enlace público de Memory Honduras
After=network-online.target memory-honduras.service
Wants=network-online.target

[Service]
User=$USUARIO
ExecStart=$NGROK http --url=$URL_NGROK 3000 --log=stdout
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now memory-honduras.service
sudo systemctl enable --now ngrok-memory.service

echo
echo "Esperando a que arranquen..."
sleep 6
for s in memory-honduras ngrok-memory; do
  printf '%-18s %s\n' "$s" "$(systemctl is-active "$s")"
done
if curl -s -m 5 http://localhost:3000/api/salud | grep -q '"ok":true'; then
  echo "Servidor: OK"
else
  echo "Servidor: NO responde. Revisa: journalctl -u memory-honduras -n 30"
fi
if curl -s -m 10 -H 'ngrok-skip-browser-warning: 1' "$URL_NGROK/api/salud" | grep -q '"ok":true'; then
  echo "Enlace público ($URL_NGROK): OK"
else
  echo "Enlace público: todavía no responde. Revisa: journalctl -u ngrok-memory -n 30"
fi
