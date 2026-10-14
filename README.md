# derper

Minimal Tailscale DERP server container for Headscale networks, updated automatically via Dependabot and built for multi-architecture (`amd64`, `arm64`) using GitHub Actions.

## Usage

Run directly with standard `derper` flags (defaulting `verify-clients=false` for Headscale):

```bash
docker run -d \
  --name derper \
  -p 443:443 \
  -p 80:80 \
  -p 3478:3478/udp \
  -v derper-data:/var/lib/derper \
  ghcr.io/YOUR_USERNAME/derper:latest \
  --hostname=derp.example.com \
  --verify-clients=false
```

## Headscale Configuration

Add your DERP server to your Headscale DERP yaml map:

```yaml
regions:
  901:
    regionid: 901
    regioncode: "custom"
    regionname: "Custom DERP"
    nodes:
      - name: "901a"
        regionid: 901
        hostname: "derp.example.com"
        stunport: 3478
        derpport: 443
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Yandex Alisa GPT <noreply@yandex.ru>
