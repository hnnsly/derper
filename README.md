# derper

Tailscale DERP relay server container for Headscale networks. Pinned to upstream `tailscale.com/cmd/derper`, tracked by Dependabot, and built for `linux/amd64` and `linux/arm64` via GitHub Actions.

## Deploy with Docker Compose

### 1. Standalone (Let's Encrypt)

Use this when port 80 and 443 are free on your server. Derper handles ACME certificates directly.

```yaml
services:
  derper:
    image: ghcr.io/hnnsly/derper:latest
    container_name: derper
    restart: unless-stopped
    ports:
      - "443:443"
      - "80:80"
      - "3478:3478/udp"
    volumes:
      - derper-data:/var/lib/derper
    command:
      - --hostname=derp.example.com
      - --certmode=letsencrypt
      - --verify-clients=false

volumes:
  derper-data:
```

### 2. Behind a Reverse Proxy (Caddy, Traefik, Nginx)

Use this when your server already runs a reverse proxy on ports 80/443. Derper runs in plaintext mode on an internal port while STUN UDP remains mapped directly to the host.

```yaml
services:
  derper:
    image: ghcr.io/hnnsly/derper:latest
    container_name: derper
    restart: unless-stopped
    ports:
      # Expose STUN directly on UDP
      - "3478:3478/udp"
      # Expose internal HTTP port for your host reverse proxy (or put behind a shared docker network)
      - "127.0.0.1:8080:8080"
    volumes:
      - derper-data:/var/lib/derper
    command:
      - --hostname=derp.example.com
      - --certmode=none
      - --a=:8080
      - --http-port=-1
      - --verify-clients=false

volumes:
  derper-data:
```

Example Caddy snippet:

```caddy
derp.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

Example Nginx snippet:

```nginx
server {
    server_name derp.example.com;
    listen 443 ssl http2;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
    }
}
```

### 3. Custom Mounted Certificates

If you already have TLS certificates on disk:

```yaml
services:
  derper:
    image: ghcr.io/hnnsly/derper:latest
    container_name: derper
    restart: unless-stopped
    ports:
      - "443:443"
      - "3478:3478/udp"
    volumes:
      - /path/to/certs:/app/certs:ro
      - derper-data:/var/lib/derper
    command:
      - --hostname=derp.example.com
      - --certmode=manual
      - --certdir=/app/certs
      - --http-port=-1
      - --verify-clients=false

volumes:
  derper-data:
```

Derper expects `/app/certs/derp.example.com.crt` and `/app/certs/derp.example.com.key`.

## Headscale Configuration

Add the DERP region to your Headscale `derp.yaml` file:

```yaml
regions:
  901:
    regionid: 901
    regioncode: "custom"
    regionname: "Custom DERP Relay"
    nodes:
      - name: "901a"
        regionid: 901
        hostname: "derp.example.com"
        stunport: 3478
        derpport: 443
```

Point Headscale's `config.yaml` to the file:

```yaml
derp:
  server:
    enabled: false
  urls: []
  paths:
    - /etc/headscale/derp.yaml
```

Verify reachability from any connected node:

```bash
tailscale netcheck
```
