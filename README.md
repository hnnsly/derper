# Tailscale DERP Server for Headscale

Automated container image generation pipeline for Tailscale's DERP (Designated Encrypted Relay for Packets) server, updated via Dependabot and built with GitHub Actions for multi-architecture deployments (`linux/amd64` and `linux/arm64`).

## Architecture & How It Works

1. **Dependency Pinning (`go.mod`)**: The repository pins `tailscale.com` as a Go module dependency via `tools.go`.
2. **Dependabot Automated Updates**: Dependabot monitors upstream `tailscale.com` releases daily, opening automated pull requests whenever Tailscale publishes updates. It also tracks Dockerfile base images and GitHub Actions.
3. **GitHub Actions Build Pipeline**: On every merge to `main`, Docker Buildx compiles multi-architecture images and pushes them to GitHub Container Registry (`ghcr.io`) tagged with the exact Tailscale version, commit SHA, and `latest`.
4. **Headscale Compatibility**: Standard DERP servers enforce client authentication against `tailscale.com`. This image defaults `DERP_VERIFY_CLIENTS=false`, allowing Headscale-managed nodes to relay packets through your DERP node.

## Port Requirements & Firewall Configuration

Configure your firewall or cloud security groups to permit:

| Port | Protocol | Purpose | Required When |
| :--- | :--- | :--- | :--- |
| `3478` | UDP | STUN server for NAT discovery | Always |
| `443` | TCP | DERP HTTPS relay traffic | Direct TLS or reverse proxy |
| `80` | TCP | ACME HTTP-01 challenge | Direct Let's Encrypt mode |

## Deployment Options

### Option 1: Standalone Deployment (Built-in Let's Encrypt)

Derper handles TLS certificate acquisition directly. Ensure your DNS A/AAAA record points to the server and ports `80/tcp`, `443/tcp`, and `3478/udp` are open.

Create `docker-compose.yml`:

```yaml
services:
  derper:
    image: ghcr.io/YOUR_USERNAME/derper:latest
    container_name: derper
    restart: unless-stopped
    ports:
      - "443:443"
      - "80:80"
      - "3478:3478/udp"
    environment:
      - DERP_HOST=derp.example.com
      - DERP_CERT_MODE=letsencrypt
      - DERP_ADDR=:443
      - DERP_HTTP_PORT=80
      - DERP_STUN=true
      - DERP_STUN_PORT=3478
      - DERP_VERIFY_CLIENTS=false
    volumes:
      - derper-certs:/app/certs
      - derper-data:/app/data

volumes:
  derper-certs:
  derper-data:
```

Start the service:

```bash
docker compose up -d
```

### Option 2: Reverse Proxy Mode (Caddy, Traefik, Nginx)

If port 443 is already occupied by a reverse proxy, configure derper to run without TLS (`DERP_CERT_MODE=none`) and proxy HTTP traffic to it. UDP port 3478 for STUN must still be mapped directly.

Create `docker-compose.yml`:

```yaml
services:
  caddy:
    image: caddy:2-alpine
    container_name: derper-caddy
    restart: unless-stopped
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    depends_on:
      - derper

  derper:
    image: ghcr.io/YOUR_USERNAME/derper:latest
    container_name: derper
    restart: unless-stopped
    ports:
      - "3478:3478/udp"
    environment:
      - DERP_HOST=derp.example.com
      - DERP_CERT_MODE=none
      - DERP_ADDR=:8080
      - DERP_HTTP_PORT=-1
      - DERP_STUN=true
      - DERP_STUN_PORT=3478
      - DERP_VERIFY_CLIENTS=false
    volumes:
      - derper-data:/app/data

volumes:
  caddy-data:
  caddy-config:
  derper-data:
```

Matching `Caddyfile`:

```caddy
derp.example.com {
    reverse_proxy derper:8080
}
```

### Option 3: Manual Certificates

Place `<DERP_HOST>.crt` and `<DERP_HOST>.key` inside the volume mapped to `/app/certs`:

```yaml
    environment:
      - DERP_HOST=derp.example.com
      - DERP_CERT_MODE=manual
      - DERP_CERT_DIR=/app/certs
      - DERP_ADDR=:443
      - DERP_HTTP_PORT=-1
      - DERP_VERIFY_CLIENTS=false
    volumes:
      - /path/to/host/certs:/app/certs:ro
      - derper-data:/app/data
```

## Environment Variables Reference

| Variable | Default | Description |
| :--- | :--- | :--- |
| `DERP_HOST` | *(empty)* | Public FQDN (required for Let's Encrypt) |
| `DERP_CERT_MODE` | `letsencrypt` | `letsencrypt`, `manual`, or `none` |
| `DERP_CERT_DIR` | `/app/certs` | Directory where certificates reside |
| `DERP_ADDR` | `:443` | Main TCP listen address |
| `DERP_HTTP_PORT` | `80` (or `-1`) | Port for ACME challenges; set `-1` to disable |
| `DERP_STUN` | `true` | Enable built-in STUN service |
| `DERP_STUN_PORT` | `3478` | UDP port for STUN discovery |
| `DERP_DATA_DIR` | `/app/data` | Directory where `derper.key` persists |
| `DERP_CONFIG_PATH`| `/app/data/derper.key` | Full path to the private key configuration |
| `DERP_VERIFY_CLIENTS` | `false` | Verify Tailscale clients (keep `false` for Headscale) |
| `DERP_DEV` | `false` | Enable development mode on localhost |

## Headscale Integration

Add your custom DERP server to Headscale configuration.

### YAML DERP Map Format

In Headscale's `derp.yaml` (or via `derp.paths` in `config.yaml`):

```yaml
regions:
  901:
    regionid: 901
    regioncode: "custom-derp"
    regionname: "Custom DERP Relay"
    nodes:
      - name: "901a"
        regionid: 901
        hostname: "derp.example.com"
        stunport: 3478
        stunonly: false
        derpport: 443
```

### JSON DERP Map Format

If hosting your DERP map file over HTTPS:

```json
{
  "Regions": {
    "901": {
      "RegionID": 901,
      "RegionCode": "custom-derp",
      "RegionName": "Custom DERP Relay",
      "Nodes": [
        {
          "Name": "901a",
          "RegionID": 901,
          "HostName": "derp.example.com",
          "STUNPort": 3478,
          "DERPPort": 443,
          "STUNOnly": false
        }
      ]
    }
  }
}
```

Point Headscale to this configuration file in `config.yaml`:

```yaml
derp:
  server:
    enabled: false
  urls: []
  paths:
    - /etc/headscale/derp.yaml
```

## Verification

From any machine running Tailscale connected to your Headscale network:

```bash
tailscale netcheck
```

The output will include your custom DERP region (`custom-derp` / region `901`) with direct UDP latency and DERP round-trip time:

```text
Report:
	* UDP: true
	* IPv4: yes, 203.0.113.45:41641
	* IPv6: no
	* Mapping VarScan: no
	* PortMapping: UPnP, NAT-PMP
	* CaptivePortal: false
	* Nearest DERP: custom-derp (901)
	* DERP latency:
		- 901: 18.4ms (custom-derp)
```
