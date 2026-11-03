# Agente de monitoreo

Esta rama contiene el agente Grafana Alloy. La configuración principal está preparada para un equipo **Windows** detrás de una red corporativa: recolecta métricas del host y las envía por una conexión saliente a Prometheus en `134.122.28.193`. No abre puertos entrantes en el equipo agente.

> **Requisito de servidor:** el servidor central debe estar desplegado desde la rama `main` y aceptar `9090/tcp` desde la IP pública de salida de la red corporativa. Esta configuración usa HTTP sin cifrar y el receptor Remote Write de Prometheus no tiene autenticación integrada. Para producción, prefiere VPN o HTTPS con autenticación.

## Windows: instalación nativa de Alloy

1. Verifica desde PowerShell la IP pública de salida de la red corporativa:

   ```powershell
   (Invoke-RestMethod https://api.ipify.org).Trim()
   ```

   Esa IP debe estar permitida para `9090/tcp` en el Cloud Firewall de DigitalOcean y en el firewall del Droplet.

2. Clona esta rama e instala Alloy desde PowerShell:

   ```powershell
   git clone --branch agente https://github.com/MU5741N3/grafanaj.git
   cd grafanaj
   winget install --id GrafanaLabs.Alloy -e
   ```

3. Abre PowerShell como administrador y copia la configuración al directorio de Alloy:

   ```powershell
   Copy-Item .\agent\alloy\config.windows.alloy "$env:ProgramFiles\GrafanaLabs\Alloy\config.alloy" -Force
   ```

   La configuración usa `COMPUTERNAME` como nombre de la máquina. Si Alloy se instaló en una ubicación distinta, copia el archivo al `config.alloy` configurado para ese servicio.

4. Reinicia el servicio Alloy desde **Servicios** (busca “Alloy”) o reinicia Windows.

5. Comprueba conectividad hacia Prometheus:

   ```powershell
   Test-NetConnection 134.122.28.193 -Port 9090
   ```

   El resultado debe mostrar `TcpTestSucceeded: True`. Si falla, solicita que la red corporativa permita tráfico **saliente** TCP al puerto `9090`, y confirma que la IP pública corporativa esté autorizada en ambos firewalls del servidor.

6. En Grafana, abre **Monitoreo de Infraestructura → Estado de Máquinas y Conectividad (Host Status)**. El nombre del equipo aparecerá cuando Alloy haya comenzado a enviar métricas.

## Linux: Alloy en Docker (alternativa)

El compose y `config.alloy` de esta rama son para agentes Linux. En la carpeta `agent/alloy`, confirma el nombre del equipo en `docker-compose.agent.yml` y ejecuta:

```bash
docker compose -f docker-compose.agent.yml up -d
docker compose -f docker-compose.agent.yml logs -f alloy
```

El agente también envía a `http://134.122.28.193:9090/api/v1/write`. Permite la salida TCP `9090` desde la red cliente y no abras puertos entrantes en esa máquina.

## Diagnóstico

- **El puerto no responde:** revisar salida TCP `9090` corporativa, la IP de origen autorizada y el Cloud Firewall del Droplet.
- **El equipo no aparece en Grafana:** revisar que el servicio Alloy esté iniciado y su configuración apunte a `134.122.28.193`.
- **Las métricas no se envían:** consultar el registro del servicio Alloy en el Visor de eventos de Windows o los logs del contenedor Linux.
