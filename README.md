# Monitoreo de Estado y Disponibilidad de Máquinas con Grafana

Este proyecto proporciona una solución para probar y monitorear cuándo una máquina remota está **activa (online/up)** o **caída (offline/down)**, mediante la conexión de agentes a un servidor central de Grafana.

> **Seguridad:** por defecto, Grafana y Prometheus solo escuchan en `localhost`; no están disponibles desde otras máquinas. La contraseña inicial de Grafana es `admin` y debe cambiarse al primer inicio de sesión. No expongas directamente Prometheus ni su endpoint de escritura remota a Internet. Para recibir agentes remotos, configura una red privada/VPN y una publicación de puertos protegida por firewall y autenticación.

---

## 🏗️ Arquitectura del Sistema

Grafana por sí mismo es un visualizador de datos; requiere de una base de datos de series temporales (como **Prometheus**) para recibir y almacenar el estado de los agentes.

Existen dos modalidades principales para conectar agentes:

```
[ Máquina Cliente 1 ] ---> (Agente: Node Exporter :9100) <--- [Prometheus Scrape (PULL)]
[ Máquina Cliente 2 ] ---> (Agente: Grafana Alloy) ------> [Prometheus Remote Write (PUSH)]
                                                                   │
                                                                   ▼
                                                            [ Prometheus Server ]
                                                                   │
                                                                   ▼
                                                            [ Grafana Dashboard ]
                                                      (Semáforo ACTIVA / INACTIVA)
```

1. **Modelo PULL (Recomendado para redes locales / VPN):**
   - El agente cliente ejecuta **Node Exporter** (puerto `9100`).
   - El servidor central Prometheus consulta periódicamente el estado de cada máquina.
   - Si la máquina no responde en un intervalo, Prometheus asigna el valor `up = 0` (Inactiva).

2. **Modelo PUSH (Recomendado para máquinas detrás de NAT / Firewall sin IPs públicas fijas):**
   - El agente cliente ejecuta **Grafana Alloy** (el agente unificado y moderno de Grafana).
   - El agente recopila las métricas del sistema y las envía de forma saliente (*remote_write*) hacia el puerto `9090` del servidor central.

---

## 🚀 Paso 1: Iniciar el Servidor Central (Grafana + Prometheus)

En la máquina o servidor que servirá como central de monitoreo:

1. **Clonar este repositorio o copiar sus archivos.**
2. **Iniciar el stack central con Docker Compose:**
   ```bash
   docker compose up -d
   ```
3. **Acceder a los paneles:**
   - **Grafana:** `http://localhost:3000`
     - Usuario por defecto: `admin`
     - Contraseña por defecto: `admin`
   - **Prometheus:** `http://localhost:9090`

El datasource de Prometheus y los dashboards de disponibilidad de máquinas y **Estado de certificados SSL/TLS** se cargan automáticamente en Grafana.

### Monitorear certificados SSL/TLS de sitios

El servicio Blackbox Exporter comprueba cada 15 segundos que cada URL HTTPS responda correctamente y recopila la fecha de expiración de su certificado. Para agregar sitios, edita `prometheus/ssl-targets.yml`:

```yaml
- targets:
    - https://midominio.com
    - https://www.midominio.com
  labels:
    site: Mi sitio
```

Puedes agregar más bloques con etiquetas `site` distintas. El archivo se vuelve a leer automáticamente; los nuevos sitios aparecerán en Prometheus y en el dashboard **Estado de certificados SSL/TLS** en aproximadamente 30 segundos. El dashboard muestra disponibilidad, certificados que vencen en menos de 30 días, días restantes e histórico. Si editas el archivo, conserva YAML válido; usa `[]` cuando todavía no haya sitios.

---

## 💻 Paso 2: Conectar un Agente en las Máquinas a Monitorear

Elige una de las siguientes opciones según tu infraestructura:

### Opción A: Node Exporter con Docker (Rápido y aislado)

En la máquina cliente remota que deseas monitorear:

1. Copia la carpeta `agent/node-exporter/docker-compose.node-exporter.yml` a la máquina cliente.
2. Inicia el agente:
   ```bash
   docker compose -f docker-compose.node-exporter.yml up -d
   ```
3. En el servidor central, edita `prometheus/prometheus.yml` y añade la IP de la máquina:
   ```yaml
   - job_name: 'node_exporter'
     static_configs:
       - targets:
           - '<IP_MAQUINA_CLIENTE>:9100'
         labels:
           instance_name: 'servidor-cliente-01'
           environment: 'produccion'
   ```
4. Recarga Prometheus sin reiniciar el contenedor:
   ```bash
   curl -X POST http://localhost:9090/-/reload
   # O reinicia el contenedor central:
   docker compose restart prometheus
   ```

### Opción B: Node Exporter nativo con Systemd (Linux sin Docker)

En cualquier servidor Linux (Ubuntu, Debian, CentOS, AlmaLinux, Raspberry Pi, etc.):

1. Copia y ejecuta el script automatizado en la máquina cliente:
   ```bash
   sudo ./agent/node-exporter/install-node-exporter.sh
   ```
   *El script creará un usuario de sistema seguro, descargará el binario oficial y activará el servicio systemd `node_exporter.service` automáticamente.*
2. Registra la IP de la máquina cliente en `prometheus/prometheus.yml` en el servidor central (igual que en la Opción A).

### Opción C: Grafana Alloy (Modo PUSH - Sin abrir puertos en el cliente)

Ideal cuando la máquina cliente está detrás de un router doméstico o firewall y no puedes abrir el puerto 9100:

1. En la máquina cliente, ve a `agent/alloy/`.
2. Edita `docker-compose.agent.yml` cambiando `CENTRAL_REMOTE_WRITE_URL` por la IP o dominio público de tu central:
   ```yaml
   environment:
     - HOSTNAME=servidor-remoto-sucursal
     - CENTRAL_REMOTE_WRITE_URL=http://<IP_PUBLICA_O_VPN_CENTRAL>:9090/api/v1/write
   ```
3. Ejecuta el agente:
   ```bash
   docker compose -f docker-compose.agent.yml up -d
   ```
   *El agente enviará periódicamente sus métricas y su señal de vida a la central.*

---

## 📊 Paso 3: Visualización en Grafana

Una vez conectado el agente, entra a Grafana (`http://localhost:3000`) y dirígete al menú:
**Dashboards -> Monitoreo de Infraestructura -> Estado de Máquinas y Conectividad (Host Status)**.

El dashboard incluye:
1. **Contadores de Estado Global:** Total de máquinas monitoreadas, cuántas están en línea (Online) y cuántas están caídas (Offline).
2. **Semáforo en Tiempo Real:** Tarjetas visuales individuales para cada máquina que cambian a **Verde (`ACTIVA (UP)`)** o **Rojo (`INACTIVA (DOWN)`)**.
3. **Detalle de Conexión:** Tabla con nombre de host, dirección IP y tiempo exacto que lleva encendida la máquina (Uptime en días/horas/minutos).
4. **Histórico de Conectividad:** Gráfico cronológico para auditar micro-cortes o desconexiones pasadas.

---

## 🔔 Paso 4: Alertas de Desconexión (Notificaciones en Discord, Telegram, Slack o Correo)

Para que Grafana te avise de inmediato cuando una máquina se apaga o pierde conectividad:

1. Ve a **Alerting -> Alert rules -> New alert rule** en Grafana.
2. Configura la consulta:
   - **Data source:** `Prometheus`
   - **Query:** `up{job="node_exporter"} == 0`
3. En **Condition**, define que la alerta se dispare si el valor es `>= 1` durante `1m` (1 minuto).
4. En **Contact points**, configura tu canal preferido (Email, bot de Telegram, Webhook de Discord/Slack).
5. ¡Listo! Recibirás un mensaje automático tan pronto como un agente deje de reportar.
