# Agente Linux de monitoreo

Esta rama contiene Grafana Alloy configurado para un **host Linux** detrás de una red corporativa. Alloy recopila métricas del host y las envía mediante una conexión saliente al Prometheus central en `134.122.28.193`. No se abren puertos entrantes en la máquina agente.

> **Requisito de servidor:** el servidor debe estar desplegado desde la rama `main`. El firewall de DigitalOcean y el del Droplet deben permitir `9090/tcp` desde la IP pública de salida de la red corporativa. La configuración actual usa HTTP sin cifrar y el receptor Remote Write de Prometheus no tiene autenticación. Para producción, usa HTTPS con autenticación o una VPN.

## Requisitos

- Linux con Docker Engine y el plugin Docker Compose.
- Acceso de salida por TCP al puerto `9090` de `134.122.28.193`.
- La IP pública de salida de la red corporativa autorizada en el Cloud Firewall de DigitalOcean y en el firewall del Droplet.

## Instalación y arranque

1. Clona la rama `agente` y entra al repositorio:

   ```bash
   git clone --branch agente https://github.com/MU5741N3/grafanaj.git
   cd grafanaj
   ```

2. Edita `agent/alloy/docker-compose.agent.yml` y cambia `HOSTNAME` por un nombre único para este equipo:

   ```yaml
   - HOSTNAME=servidor-sucursal-01
   ```

   El destino de Remote Write ya está configurado como `http://134.122.28.193:9090/api/v1/write`.

3. Inicia Alloy:

   ```bash
   docker compose -f agent/alloy/docker-compose.agent.yml up -d
   ```

4. Comprueba los logs del agente:

   ```bash
   docker compose -f agent/alloy/docker-compose.agent.yml logs -f alloy
   ```

   Comprueba la conectividad al servidor con `curl -sS http://134.122.28.193:9090/-/healthy`. La respuesta debe ser `Prometheus Server is Ready.` Si falla la conexión, verifica la salida corporativa TCP `9090` y las reglas de firewall del Droplet.

5. En Grafana, abre **Monitoreo de Infraestructura → Estado de Máquinas y Conectividad (Host Status)**. El equipo aparecerá cuando Alloy comience a enviar las métricas.

## Métricas del host

La configuración monta `/proc`, `/sys` y la raíz del host en solo lectura y pasa sus rutas a `prometheus.exporter.unix`. Así Alloy recopila métricas del host Linux, no las del contenedor. Los datos pendientes de Remote Write se guardan en el volumen Docker `alloy_data`.

## Seguridad

- El agente no expone puertos: inicia conexiones salientes hacia el servidor.
- Restringe `9090/tcp` en el Cloud Firewall de DigitalOcean a la IP pública de salida corporativa (`<IP_CORPORATIVA>/32`); no lo abras a todo Internet.
- El puerto `9090` no tiene autenticación y HTTP no cifra el tráfico. Usa una VPN o configura HTTPS y autenticación antes de usarlo en producción.
