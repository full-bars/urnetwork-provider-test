# --- Build Stage ---
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

ARG TARGETARCH
ARG VERSION=dev
WORKDIR /app

RUN apk add --no-cache git gcc musl-dev

COPY . .

RUN go mod download

RUN GOOS=linux GOARCH=$TARGETARCH CGO_ENABLED=0 GOEXPERIMENT=greenteagc \
    go build -trimpath \
    -ldflags "-s -w -X main.Version=${VERSION}" \
    -o provider_bin ./provider/

# --- Final Stage ---
FROM alpine:latest

ARG TARGETARCH
ARG VERSION=dev
WORKDIR /app

RUN apk update && apk add --no-cache \
    tzdata iputils vnstat dos2unix \
    jq tar curl htop wget procps \
    iptables net-tools bind-tools \
    busybox-extras ca-certificates \
    ca-certificates-bundle bash \
    gosu \
  && rm -rf /var/cache/apk/*

RUN mkdir -p /app/cgi-bin /root/.urnetwork

COPY docker/scripts/*.sh /app/
COPY docker/scripts/stats /app/cgi-bin/

COPY --from=builder /app/provider_bin /app/urnetwork_${TARGETARCH}_stable

RUN dos2unix /app/*.sh /app/cgi-bin/stats && chmod +x /app/*.sh /app/cgi-bin/stats

RUN sed -i \
  -e 's/^;*TimeSyncWait.*/TimeSyncWait 1/' \
  -e 's/^;*TrafficlessEntries.*/TrafficlessEntries 1/' \
  -e 's/^;*UpdateInterval.*/UpdateInterval 15/' \
  -e 's/^;*PollInterval.*/PollInterval 15/' \
  -e 's/^;*SaveInterval.*/SaveInterval 1/' \
  -e 's/^;*UnitMode.*/UnitMode 1/' \
  -e 's/^;*RateUnit.*/RateUnit 0/' \
  -e 's/^;*RateUnitMode.*/RateUnitMode 0/' \
  /etc/vnstat.conf

VOLUME ["/root/.urnetwork"]

ENTRYPOINT ["/app/entrypoint.sh"]
