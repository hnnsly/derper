#!/bin/sh
set -e

# If HTTP port is active, probe it
if [ "${DERP_HTTP_PORT:-}" != "-1" ] && [ "${DERP_CERT_MODE:-letsencrypt}" = "letsencrypt" ]; then
    PORT="${DERP_HTTP_PORT:-80}"
    if curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        exit 0
    fi
fi

# Probe main listen address
ADDR="${DERP_ADDR:-:443}"
PORT="${ADDR##*:}"

if [ "${DERP_CERT_MODE:-letsencrypt}" = "none" ]; then
    curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1 && exit 0
else
    # In TLS mode, accept self-signed or domain certificates when connecting to 127.0.0.1
    curl -kfsS "https://127.0.0.1:${PORT}/" >/dev/null 2>&1 && exit 0
fi

exit 1
