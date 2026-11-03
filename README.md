# Agente Linux de monitoreo

Esta rama contiene Grafana Alloy configurado para un **host Linux en una red doméstica**. Alloy recopila métricas del host y las envía mediante una conexión saliente al Prometheus central en `134.122.28.193`. No se abren puertos entrantes ni se necesita configurar port forwarding en el router de casa.

> **Requisito de servidor:** el servidor debe estar desplegado desde la rama `main`. El Cloud Firewall de DigitalOcean debe permitir `9090/tcp` desde la IP pública de tu conexión doméstica. La configuración actual usa HTTP sin cifrar y el receptor Remote Write de Prometheus no tiene autenticación. No abras ese puerto a todo Internet; para producción, usa HTTPS con autenticación o una VPN.

## Requisitos

- Linux con Docker Engine y el plugin Docker Compose.
- Acceso de salida por TCP al puerto `9090` de `134.122.28.193`.
- La IP pública de salida de tu casa autorizada en el Cloud Firewall de DigitalOcean.
- El router doméstico debe permitir conexiones salientes; normalmente no requiere ningún cambio.

## Instalación y arranque

1. Clona la rama `agente` y entra al repositorio:

   ```bash
   git clone --branch agente https://github.com/MU5741N3/grafanaj.git
   cd grafanaj
   ```

2. Desde la red doméstica, consulta tu IP pública actual:

   ```bash
   curl -4 https://api.ipify.org
   ```

   Autoriza esa IP como origen (`<IP_CASA>/32`) para `9090/tcp` en el Cloud Firewall de DigitalOcean. Si el firewall del Droplet también aplica reglas, permite allí la misma IP.

3. Edita `agent/alloy/docker-compose.agent.yml` y cambia `HOSTNAME` por un nombre único para este equipo:

   ```yaml
   - HOSTNAME=servidor-sucursal-01
   ```

   El destino de Remote Write ya está configurado como `http://134.122.28.193:9090/api/v1/write`.

4. Inicia Alloy:

   ```bash
   docker compose -f agent/alloy/docker-compose.agent.yml up -d
   ```

5. Comprueba los logs del agente:

   ```bash
   docker compose -f agent/alloy/docker-compose.agent.yml logs -f alloy
   ```

   Comprueba la conectividad al servidor con `curl -sS http://134.122.28.193:9090/-/healthy`. La respuesta debe ser `Prometheus Server is Ready.` Si falla la conexión, verifica que el router permita salida TCP `9090` y que la IP pública actual de casa esté autorizada en el Cloud Firewall.

6. En Grafana, abre **Monitoreo de Infraestructura → Estado de Máquinas y Conectividad (Host Status)**. El equipo aparecerá cuando Alloy comience a enviar las métricas.

## IP doméstica dinámica

Las conexiones residenciales suelen tener una IP pública dinámica. Si tu proveedor la cambia, el agente seguirá intentando enviar métricas, pero el Cloud Firewall bloqueará la nueva IP. Consulta otra vez la IP con `curl -4 https://api.ipify.org` y actualiza la regla de origen en el firewall de DigitalOcean a `<NUEVA_IP>/32`. No soluciones el problema permitiendo `0.0.0.0/0`, porque el endpoint de escritura no tiene autenticación.

## Métricas del host

La configuración monta `/proc`, `/sys` y la raíz del host en solo lectura y pasa sus rutas a `prometheus.exporter.unix`. Así Alloy recopila métricas del host Linux, no las del contenedor. Los datos pendientes de Remote Write se guardan en el volumen Docker `alloy_data`.

## Seguridad

- El agente no expone puertos: inicia conexiones salientes hacia el servidor. No configures port forwarding en el router.
- Restringe `9090/tcp` en el Cloud Firewall de DigitalOcean a la IP pública doméstica (`<IP_CASA>/32`); no lo abras a todo Internet.
- El puerto `9090` no tiene autenticación y HTTP no cifra el tráfico. Usa una VPN o configura HTTPS y autenticación antes de usarlo en producción.
