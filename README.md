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

The provider needs to lose connectivity to the URnetwork platform while your SSH session stays alive. Use one of the two approaches below depending on whether you're running Docker or the binary.

### Docker — container network namespace

Containers are already isolated. Use `nsenter` to apply rules inside the container only.

```sh
# Get the container's PID
PID=$(docker inspect --format '{{.State.Pid}}' urnetwork-test)

# Stage 1: degrade (high latency + packet loss)
sudo nsenter -t $PID -n -- tc qdisc add dev eth0 root netem delay 800ms loss 25%

# Stage 2: full outage
sudo nsenter -t $PID -n -- iptables -A OUTPUT -d connect.bringyour.com -j DROP
sudo nsenter -t $PID -n -- iptables -A OUTPUT -d api.bringyour.com -j DROP

# Restore
sudo nsenter -t $PID -n -- tc qdisc del dev eth0 root 2>/dev/null || true
sudo nsenter -t $PID -n -- iptables -D OUTPUT -d connect.bringyour.com -j DROP
sudo nsenter -t $PID -n -- iptables -D OUTPUT -d api.bringyour.com -j DROP
```

### Binary — dedicated system user + `--uid-owner`

Run the provider as its own system user. iptables rules target that UID only — your SSH session is unaffected.

**One-time setup:**
```sh
sudo useradd -r -M -s /bin/false urnetwork-tester
sudo mkdir -p /opt/urnetwork-test /var/lib/urnetwork-test
sudo cp ~/.local/share/urnetwork-provider-test/bin/urnetwork /opt/urnetwork-test/urnetwork
sudo chown -R urnetwork-tester:urnetwork-tester /opt/urnetwork-test /var/lib/urnetwork-test
```

**Authenticate and run:**
```sh
sudo -u urnetwork-tester HOME=/var/lib/urnetwork-test \
  /opt/urnetwork-test/urnetwork auth \
  --user_auth=YOUR@EMAIL.COM --password=YOURPASSWORD -f

sudo -u urnetwork-tester HOME=/var/lib/urnetwork-test \
  /opt/urnetwork-test/urnetwork provide 2>&1 | tee /tmp/ur-test.log
```

**Stage 1: degrade — provider UID only:**
```sh
sudo iptables -A OUTPUT \
  -m owner --uid-owner urnetwork-tester \
  -d connect.bringyour.com \
  -m statistic --mode random --probability 0.4 -j DROP
```

**Stage 2: full outage — provider UID only:**
```sh
sudo iptables -A OUTPUT -m owner --uid-owner urnetwork-tester \
  -d connect.bringyour.com -j DROP
sudo iptables -A OUTPUT -m owner --uid-owner urnetwork-tester \
  -d api.bringyour.com -j DROP
```

**Restore:**
```sh
sudo iptables -D OUTPUT -m owner --uid-owner urnetwork-tester \
  -d connect.bringyour.com -m statistic --mode random --probability 0.4 -j DROP 2>/dev/null || true
sudo iptables -D OUTPUT -m owner --uid-owner urnetwork-tester \
  -d connect.bringyour.com -j DROP 2>/dev/null || true
sudo iptables -D OUTPUT -m owner --uid-owner urnetwork-tester \
  -d api.bringyour.com -j DROP 2>/dev/null || true
```

---

## Expected log behavior during outage

| | Without PR#180 | With PR#180 |
|---|---|---|
| `[contract]oob err` | Every few seconds | At most once per minute |
| `[t]auth error` | Every 5s per transport | Once per failure session |

---

## Related

- PR: https://github.com/urnetwork/connect/pull/180
- Bandwidth leak issue: https://github.com/urnetwork/connect/issues/181
- Upstream repo: https://github.com/urnetwork/connect
