# urnetwork-provider-test

Test build of [urnetwork/connect PR#180](https://github.com/urnetwork/connect/pull/180) — reduces log spam during backend outages.

**Do not use in production.** This is a test build for validating the PR changes described in [#180](https://github.com/urnetwork/connect/pull/180).

---

## What this tests

During URnetwork backend outages, two log lines previously fired on every retry cycle:

```
[contract]oob err = Timeout
[t]auth error <id> = No successful strategy found.
```

PR#180 reduces these to at most once per minute and once per failure session respectively.

---

## Binary install (recommended for outage testing)

### Install

```sh
curl -fsSL https://raw.githubusercontent.com/full-bars/urnetwork-provider-test/main/scripts/install.sh | sh
```

Installs to `~/.local/share/urnetwork-provider-test/bin/urnetwork` and registers a systemd user service.

### Authenticate

```sh
~/.local/share/urnetwork-provider-test/bin/urnetwork auth \
  --user_auth=YOUR@EMAIL.COM \
  --password=YOURPASSWORD \
  -f
```

### Start

```sh
systemctl --user enable --now urnetwork-test.service
```

### Watch logs

```sh
journalctl --user -u urnetwork-test.service -f
```

### Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/full-bars/urnetwork-provider-test/main/scripts/uninstall.sh | sh
```

---

## Docker

### Run (password auth)

```sh
docker run -d \
  --name urnetwork-test \
  --restart unless-stopped \
  -e BUILD=stable \
  -e USER_AUTH=YOUR@EMAIL.COM \
  -e PASSWORD=YOURPASSWORD \
  -v ~/.urnetwork:/root/.urnetwork \
  ghcr.io/full-bars/urnetwork-provider-test:latest
```

### Run (JWT auth)

```sh
docker run -d \
  --name urnetwork-test \
  --restart unless-stopped \
  -e BUILD=jwt \
  -v ~/.urnetwork:/root/.urnetwork \
  ghcr.io/full-bars/urnetwork-provider-test:latest \
  YOUR_AUTH_TOKEN
```

### Watch logs

```sh
docker logs -f urnetwork-test
```

### Stop and remove

```sh
docker stop urnetwork-test && docker rm urnetwork-test
```

---

## Simulating an outage without breaking SSH

Use `tc netem` inside the container's network namespace. This operates at the NIC level and affects all traffic regardless of connection state or DNS cache — unlike iptables hostname rules which are bypassed by already-established connections and cached IPs.

The container is already isolated from the host, so your SSH session is unaffected.

```sh
# Get the container's PID
PID=$(docker inspect --format '{{.State.Pid}}' urnetwork-test)

# Stage 1: degrade (high latency + packet loss)
sudo nsenter -t $PID -n -- tc qdisc add dev eth0 root netem delay 2000ms loss 50%

# Restore
sudo nsenter -t $PID -n -- tc qdisc del dev eth0 root 2>/dev/null || true
```

**Note:** `iptables -d hostname` rules were tested and found ineffective — the provider resolves platform hostnames at startup and maintains persistent connections, so hostname-based DROP rules have no effect on already-established or cached sessions. `tc netem` is the correct tool for this test.

---

## Expected log behavior during outage

| | Without PR#180 | With PR#180 |
|---|---|---|
| `[contract]oob err` | Every few seconds | At most once per minute (atomic check-and-set) |
| `[t]auth error` | Every 5s per transport | At most once per minute globally across all transports |

---

## Related

- PR: https://github.com/urnetwork/connect/pull/180
- Bandwidth leak issue: https://github.com/urnetwork/connect/issues/181
- Upstream repo: https://github.com/urnetwork/connect
