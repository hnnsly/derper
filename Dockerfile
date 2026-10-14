# syntax=docker/dockerfile:1

# Stage 1: Build derper binary
FROM golang:1.27.2-alpine AS builder

WORKDIR /src

# Copy module definitions first to maximize layer caching
COPY go.mod go.sum tools.go ./
RUN go mod download

# Build static binary without CGO
RUN CGO_ENABLED=0 go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /app/derper \
    tailscale.com/cmd/derper

# Stage 2: Minimal runtime image
FROM alpine:3.24.2

# Install runtime dependencies: ca-certificates for TLS, curl for health checks
RUN apk --no-cache add ca-certificates curl

# Create unprivileged user and directories
RUN addgroup -g 10001 -S derper && \
    adduser -u 10001 -S derper -G derper && \
    mkdir -p /app/certs /app/data && \
    chown -R derper:derper /app

WORKDIR /app

COPY --from=builder /app/derper /app/derper
COPY entrypoint.sh /app/entrypoint.sh
COPY healthcheck.sh /app/healthcheck.sh

RUN chmod +x /app/entrypoint.sh /app/healthcheck.sh

USER 10001:10001

EXPOSE 443 80 3478/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD ["/app/healthcheck.sh"]

ENTRYPOINT ["/app/entrypoint.sh"]
