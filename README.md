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

## Binary install (recommended for testing with tc/iptables)

### Install

```sh
curl -fsSL https://raw.githubusercontent.com/full-bars/urnetwork-provider-test/main/scripts/install.sh | sh
```

This installs the provider binary to `~/.local/share/urnetwork-provider-test/bin/urnetwork` and registers a systemd user service.

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
  YOUR_JWT_TOKEN
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

## Simulating an outage (for testing)

Once the provider has warmed up and is moving traffic (~8 hours), use the following to simulate backend degradation:

### Gradual degradation (high latency + packet loss)

```sh
tc qdisc add dev eth0 root netem delay 800ms loss 25%
```

### Full outage (block platform endpoints)

```sh
iptables -A OUTPUT -d connect.bringyour.com -j DROP
iptables -A OUTPUT -d api.bringyour.com -j DROP
```

### Restore

```sh
tc qdisc del dev eth0 root 2>/dev/null || true
iptables -D OUTPUT -d connect.bringyour.com -j DROP
iptables -D OUTPUT -d api.bringyour.com -j DROP
```

### Expected log behavior during outage

| | Without PR#180 | With PR#180 |
|---|---|---|
| `[contract]oob err` | Every few seconds | At most once per minute |
| `[t]auth error` | Every 5s per transport | Once per failure session |

---

## Related

- PR: https://github.com/urnetwork/connect/pull/180
- Bandwidth leak issue: https://github.com/urnetwork/connect/issues/181
- Upstream repo: https://github.com/urnetwork/connect
