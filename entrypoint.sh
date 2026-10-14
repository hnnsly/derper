#!/bin/sh
set -e

# Fast-path for version and help queries
if [ "$1" = "-version" ] || [ "$1" = "--version" ] || [ "$1" = "-help" ] || [ "$1" = "--help" ]; then
    exec /app/derper "$@"
fi

# Strip optional "derper" prefix if passed
if [ "$1" = "derper" ]; then
    shift
    if [ "$1" = "-version" ] || [ "$1" = "--version" ] || [ "$1" = "-help" ] || [ "$1" = "--help" ]; then
        exec /app/derper "$@"
    fi
fi

# If user passed custom command or binary name, execute directly
if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
    exec "$@"
fi

# Directory preparation
mkdir -p "${DERP_CERT_DIR:-/app/certs}" "${DERP_DATA_DIR:-/app/data}"

# Resolve hostname
HOST="${DERP_HOST:-${DERP_HOSTNAME:-}}"
CERT_MODE="${DERP_CERT_MODE:-letsencrypt}"

ARGS=""

if [ -n "$HOST" ]; then
    ARGS="$ARGS -hostname=$HOST"
elif [ "$CERT_MODE" = "letsencrypt" ]; then
    echo "ERROR: DERP_HOST (or DERP_HOSTNAME) is required when DERP_CERT_MODE=letsencrypt" >&2
    exit 1
fi

ARGS="$ARGS -certmode=$CERT_MODE"
ARGS="$ARGS -certdir=${DERP_CERT_DIR:-/app/certs}"
ARGS="$ARGS -a=${DERP_ADDR:-:443}"
ARGS="$ARGS -c=${DERP_CONFIG_PATH:-/app/data/derper.key}"
ARGS="$ARGS -stun=${DERP_STUN:-true}"
ARGS="$ARGS -stun-port=${DERP_STUN_PORT:-3478}"
ARGS="$ARGS -verify-clients=${DERP_VERIFY_CLIENTS:-false}"

# HTTP port handling: default to 80 for letsencrypt, -1 (disabled) for none/manual unless set
if [ -n "${DERP_HTTP_PORT:-}" ]; then
    ARGS="$ARGS -http-port=$DERP_HTTP_PORT"
elif [ "$CERT_MODE" = "none" ] || [ "$CERT_MODE" = "manual" ]; then
    ARGS="$ARGS -http-port=-1"
else
    ARGS="$ARGS -http-port=80"
fi

if [ -n "${DERP_VERIFY_CLIENT_URL:-}" ]; then
    ARGS="$ARGS -verify-client-url=$DERP_VERIFY_CLIENT_URL"
fi

if [ -n "${DERP_VERIFY_CLIENT_URL_FAIL_OPEN:-}" ]; then
    ARGS="$ARGS -verify-client-url-fail-open=$DERP_VERIFY_CLIENT_URL_FAIL_OPEN"
fi

if [ -n "${DERP_MESH_PSK_FILE:-}" ]; then
    ARGS="$ARGS -mesh-psk-file=$DERP_MESH_PSK_FILE"
fi

if [ -n "${DERP_MESH_WITH:-}" ]; then
    ARGS="$ARGS -mesh-with=$DERP_MESH_WITH"
fi

if [ -n "${DERP_BOOTSTRAP_DNS_NAMES:-}" ]; then
    ARGS="$ARGS -bootstrap-dns-names=$DERP_BOOTSTRAP_DNS_NAMES"
fi

if [ "${DERP_DEV:-false}" = "true" ]; then
    ARGS="$ARGS -dev"
fi

# Run derper with assembled arguments and any trailing custom arguments
# shellcheck disable=SC2086
exec /app/derper $ARGS "$@"
