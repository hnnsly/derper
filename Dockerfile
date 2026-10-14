# syntax=docker/dockerfile:1

FROM golang:1.27.2-alpine AS builder

WORKDIR /src
COPY go.mod go.sum tools.go ./
RUN go mod download

RUN CGO_ENABLED=0 go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /app/derper \
    tailscale.com/cmd/derper

FROM alpine:3.24.2

RUN apk --no-cache add ca-certificates && \
    addgroup -g 10001 -S derper && \
    adduser -u 10001 -S derper -G derper && \
    mkdir -p /var/lib/derper && \
    chown -R derper:derper /var/lib/derper

WORKDIR /app
COPY --from=builder /app/derper /app/derper

USER 10001:10001

EXPOSE 443 80 3478/udp

ENTRYPOINT ["/app/derper"]
