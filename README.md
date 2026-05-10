
# Hypersnap Node Panel

A self-hosted monitoring dashboard for your [Hypersnap](https://github.com/farcasterorg/hypersnap) node.  
Installed in one command. HTTPS out of the box. No domain required.

> **Community tool.** Independent and not affiliated with the Hypersnap / farcasterorg team.  
> Built to make node monitoring accessible to everyone running part of the network.

---

## Install

```bash
curl -sSL https://raw.githubusercontent.com/0xsoli/hypersnap-panel/main/install-panel.sh -o /tmp/install-panel.sh && sudo bash /tmp/install-panel.sh
```

The script asks for a username and password, then handles everything else automatically:

```
  Username [default: admin]: admin
  Password (min 8 chars): ••••••••
  Confirm password: ••••••••
```

When it finishes, your panel is live at:

```
https://YOUR-IP-WITH-DASHES.sslip.io
```

Example: if your server IP is `65.21.100.4`, your panel URL is `https://65-21-100-4.sslip.io`

> First visit may take ~30 seconds while the SSL certificate is issued automatically.

---

## What the dashboard shows

| Section | Details |
|---|---|
| **Version** | Currently running node version |
| **Shards** | Number of active shards |
| **Peers** | Number of connected peers |
| **Sync Status** | Synced / Syncing / Behind — color coded automatically |
| **Shard Details** | Block height and block delay per shard with health badges |
| **Peer ID** | Full peer identity string |
| **Raw JSON** | Collapsible full `/v1/info` output |

The page auto-refreshes every 30 seconds. If the node goes offline, a clear error screen appears.

---

## How it works

```
Internet
   │  HTTPS (port 443)
   ▼
 Caddy  ──  handles TLS, terminates SSL, reverse proxies
   │  localhost only (port 5000)
   ▼
 Flask  ──  renders the dashboard, enforces auth
   │  read-only HTTP GET
   ▼
 Hypersnap Node  ──  /v1/info  (port 3381)
```

The Flask app never touches the internet directly.  
The Hypersnap node is never exposed by this tool — the panel only reads from it locally.

---

## Security

### What this tool does
- Makes one read-only `GET /v1/info` request to `127.0.0.1:3381` per page load
- Renders the response as HTML
- That's it — no writes, no commands, no access to node internals

### Layers of protection

**HTTPS / TLS**  
All traffic is encrypted via a free Let's Encrypt certificate, managed automatically by Caddy. Your password is never sent in plaintext.

**Password protection**  
HTTP Basic Auth is enforced on every request before anything is rendered. Wrong credentials return a 401 with no data.

**Hashed credentials**  
Your password is never stored in plaintext anywhere on the server. It is hashed with SHA-256 at install time. Only the hash is saved in the systemd service file, readable by root only (`chmod 600`).

**Network isolation**  
Flask binds to `127.0.0.1:5000` — not `0.0.0.0`. Port 5000 is blocked in the firewall by the installer. The only public entry point is Caddy on port 443.

**Security headers**  
Caddy adds `X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, and `Referrer-Policy` headers, and strips the `Server` header on every response.

**Read-only API**  
`/v1/info` is a public read endpoint on the Hypersnap node. It returns status information only — no keys, no write access, no sensitive credentials.

**No database, no logs, no telemetry**  
The panel stores nothing. There is no database, no session storage, no analytics, no outbound calls except to Google Fonts for typography.

### What to be aware of
- The `sslip.io` subdomain is derived from your public IP — anyone who knows your IP can guess the domain. Your password is the only gate
- Google Fonts are loaded from `fonts.googleapis.com` on each page visit — if your server operates in a restricted network environment, consider self-hosting the fonts
- For higher security environments, consider placing the panel behind a VPN or restricting port 443 to specific IPs in your cloud firewall

---

## Requirements

- Ubuntu 20.04 or newer (Debian also supported)
- Hypersnap node running and reachable at `localhost:3381`
- Root / sudo access
- Ports **80** and **443** open (for Let's Encrypt challenge and HTTPS traffic)

---

## Managing the service

```bash
# View logs (panel)
journalctl -u hypersnap-panel -f

# View logs (Caddy / HTTPS)
journalctl -u caddy -f

# Restart panel
systemctl restart hypersnap-panel

# Check status
systemctl status hypersnap-panel
systemctl status caddy
```

---

## Change credentials

Because the password is stored as a hash, you cannot edit the service file directly. Run this helper instead:

```bash
# Set new username and/or password
NEW_USER="admin"
NEW_PASS="your-new-password"

NEW_HASH=$(printf '%s' "$NEW_PASS" | python3 -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())")

sed -i \
  "s|^Environment=\"PANEL_USER=.*\"|Environment=\"PANEL_USER=${NEW_USER}\"|" \
  /etc/systemd/system/hypersnap-panel.service

sed -i \
  "s|^Environment=\"PANEL_PASS_HASH=.*\"|Environment=\"PANEL_PASS_HASH=${NEW_HASH}\"|" \
  /etc/systemd/system/hypersnap-panel.service

systemctl daemon-reload
systemctl restart hypersnap-panel
```

---

## Uninstall

```bash
systemctl stop hypersnap-panel && systemctl disable hypersnap-panel
systemctl stop caddy && systemctl disable caddy
rm /etc/systemd/system/hypersnap-panel.service
rm -rf /opt/hypersnap-panel
rm /etc/caddy/Caddyfile
systemctl daemon-reload
```

---

## Stack

| Component | Role |
|---|---|
| [Caddy](https://caddyserver.com) | Reverse proxy, automatic HTTPS via Let's Encrypt |
| [Flask](https://flask.palletsprojects.com) | Web server, auth, HTML rendering |
| [sslip.io](https://sslip.io) | Free wildcard DNS — maps IP to domain for SSL |
| systemd | Process management, auto-restart |

No npm. No build step. No containers. Pure Python + one binary.

---

## License

MIT — free to use, modify, and distribute. No warranty.

---

## Related

- [farcasterorg/hypersnap](https://github.com/farcasterorg/hypersnap) — the node this panel monitors
- [hypersnap.org/run-a-node](https://hypersnap.org/run-a-node) — official guide to running a node
- [hypersnap.org/docs](https://hypersnap.org/docs) — API reference

> Hypersnap node software is licensed under GPL-3.0. This panel is an independent community tool that communicates only via the node's local HTTP API and does not use, copy, or distribute any part of the Hypersnap source code. It is not a derivative work of Hypersnap.
