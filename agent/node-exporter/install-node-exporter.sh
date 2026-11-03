#!/usr/bin/env bash
# Script de instalación automática de Node Exporter como servicio Systemd en Linux (Ubuntu/Debian/CentOS/RHEL)
set -euo pipefail

NODE_EXPORTER_VERSION="1.7.0"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *) echo "Arquitectura no soportada: $ARCH" && exit 1 ;;
esac

echo "===> Instalando Prometheus Node Exporter v${NODE_EXPORTER_VERSION} (${ARCH})..."

# Comprobar privilegios de superusuario
if [ "$EUID" -ne 0 ]; then
  echo "Por favor ejecute este script como root o con sudo."
  exit 1
fi

# Crear usuario de sistema para node_exporter si no existe
if ! id "node_exporter" &>/dev/null; then
  useradd --no-create-home --shell /bin/false node_exporter
  echo "Usuario node_exporter creado."
fi

# Descargar y extraer binario
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
TAR_FILE="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${TAR_FILE}"

echo "Descargando desde $URL..."
curl -sSL -O "$URL"
tar -xzf "$TAR_FILE"

cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
chmod +x /usr/local/bin/node_exporter

# Limpiar archivos temporales
rm -rf "$TMP_DIR"

# Crear servicio Systemd
cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \\
    --collector.systemd \\
    --collector.processes

Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Habilitar e iniciar servicio
systemctl daemon-reload
systemctl enable --now node_exporter

echo "===> Node Exporter instalado y ejecutándose correctamente en el puerto 9100!"
echo "Verificar estado con: systemctl status node_exporter"
echo "Verificar métricas con: curl http://localhost:9100/metrics"
