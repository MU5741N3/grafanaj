# Servidor central de monitoreo

Este proyecto levanta un servidor central con **Prometheus**, **Grafana** y **Blackbox Exporter**. Recibe métricas de agentes, muestra el estado de las máquinas y vigila los certificados SSL/TLS de sitios web.

## Seguridad de red

- Grafana (`3000/tcp`) y Prometheus (`9090/tcp`) se enlazan a `127.0.0.1` por defecto.
- El receptor Remote Write de Prometheus no tiene autenticación integrada. No abras el puerto `9090` a todo Internet.
- Para aceptar agentes remotos, permite `9090/tcp` solo desde la IP pública de salida de la red agente, usando el firewall de DigitalOcean y el del sistema.
- El ejemplo usa HTTP sin cifrar. Para producción, usa una VPN o HTTPS con autenticación delante de Prometheus.
- Cambia la contraseña predeterminada de Grafana (`admin`) en el primer inicio de sesión.

## Desplegar en DigitalOcean

Los siguientes pasos suponen un Droplet con Ubuntu y la IP pública `134.122.28.193`.

1. En el Cloud Firewall de DigitalOcean, permite SSH (`22/tcp`) solo desde tu IP administrativa y Prometheus (`9090/tcp`) solo desde la IP pública de salida de la red agente (`<IP_AGENTE>/32`). No crees una regla para `0.0.0.0/0`; no publiques los puertos `3000` ni `9115`.
2. Conéctate al Droplet, instala Docker y clona la rama `main`:

   ```bash
   ssh root@134.122.28.193
   apt update
   apt install -y git docker.io docker-compose-v2
   systemctl enable --now docker
   git clone --branch main https://github.com/MU5741N3/grafanaj.git
   cd grafanaj
   ```

3. Configura UFW. Sustituye `<IP_AGENTE>` por la IP pública de salida real de la red donde correrá el agente:

   ```bash
   ufw allow OpenSSH
   ufw allow from <IP_AGENTE> to any port 9090 proto tcp
   ufw --force enable
   ```

   Puedes obtener esa IP desde la red agente con `curl https://api.ipify.org` (Linux) o `(Invoke-RestMethod https://api.ipify.org).Trim()` (PowerShell). La regla del Cloud Firewall también es obligatoria: los puertos publicados por Docker pueden no quedar restringidos por UFW.

4. Publica Prometheus en las interfaces del Droplet para que el agente pueda conectarse. El firewall debe limitar el acceso a la IP agente:

   ```bash
   printf 'PROMETHEUS_BIND_ADDRESS=0.0.0.0\n' > .env
   chmod 600 .env
   docker compose up -d
   docker compose ps
   ```

   Si no quieres recibir agentes remotamente, omite la creación de `.env`: Prometheus permanecerá enlazado a `127.0.0.1`.

## Abrir Grafana de forma segura

Grafana permanece disponible solo en el Droplet. Desde tu equipo, crea un túnel SSH:

```bash
ssh -L 3000:127.0.0.1:3000 root@134.122.28.193
```

Abre <http://localhost:3000> e inicia sesión con `admin` / `admin`; cambia la contraseña cuando te lo solicite. Prometheus puede consultarse localmente en el Droplet en <http://localhost:9090>.

## Dashboards y certificados SSL/TLS

Grafana provisiona automáticamente estos dashboards en la carpeta **Monitoreo de Infraestructura**:

- **Estado de Máquinas y Conectividad (Host Status)**: estado, disponibilidad e historial de los equipos.
- **Estado de certificados SSL/TLS**: disponibilidad HTTPS, fecha de expiración y días restantes.

Los sitios configurados para el dashboard SSL se encuentran en `prometheus/ssl-targets.yml`. Para agregar un dominio, añade una URL HTTPS:

```yaml
- targets:
    - https://midominio.com
  labels:
    site: midominio.com
```

Prometheus vuelve a leer ese archivo automáticamente cada 30 segundos. El chequeo HTTPS se ejecuta cada 15 segundos.

## Verificar la recepción de un agente

En Grafana, abre el dashboard de máquinas. También puedes comprobar en Prometheus que se reciben métricas mediante la consulta:

```promql
up{job="node_exporter"}
```

El agente debe configurarse desde la rama `agente` del repositorio. Sigue las instrucciones de su README para Windows; el agente inicia conexiones salientes y no requiere puertos entrantes en la red corporativa.
