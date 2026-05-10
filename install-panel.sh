#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║         Hypersnap Node Panel — Installer v1.0               ║
# ║         Secure · HTTPS · Mobile-Ready · Production          ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────
info()    { echo -e "  ${CYAN}${BOLD}→${RESET}  $*"; }
success() { echo -e "  ${GREEN}${BOLD}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}${BOLD}⚠${RESET}  $*"; }
die()     { echo -e "\n  ${RED}${BOLD}✗  ERROR:${RESET} $*\n"; exit 1; }
step()    { echo -e "\n  ${CYAN}[${1}/${TOTAL_STEPS}]${RESET} ${BOLD}${2}${RESET}"; }

TOTAL_STEPS=6

# ── stdin fix: always read from terminal, even when piped ───────
# This is the critical fix for `curl | bash` usage
exec </dev/tty 2>/dev/null || true

clear
echo ""
echo -e "  ${CYAN}${BOLD}┌─────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}${BOLD}│     ⬡  Hypersnap Node Panel  —  v2.0           │${RESET}"
echo -e "  ${CYAN}${BOLD}│        Secure · HTTPS · Mobile-Ready            │${RESET}"
echo -e "  ${CYAN}${BOLD}└─────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "  ${DIM}This installer will:${RESET}"
echo -e "  ${DIM}• Deploy a professional web dashboard for your node${RESET}"
echo -e "  ${DIM}• Secure it with HTTPS (free, automatic SSL)${RESET}"
echo -e "  ${DIM}• Protect it with username + password login${RESET}"
echo -e "  ${DIM}• Optimized for desktop and mobile${RESET}"
echo ""

# ── Require root ────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  die "Please run as root:\n\n  sudo bash install-panel.sh\n  — or —\n  sudo bash <(curl -s YOUR_URL)"
fi

# ── OS check ────────────────────────────────────────────────────
if ! grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
  warn "This script is tested on Ubuntu/Debian. Proceed with caution."
fi

# ── Collect inputs ──────────────────────────────────────────────
echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}Configuration${RESET}"
echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"
echo ""

# Username
while true; do
  echo -en "  ${BOLD}Username${RESET} ${DIM}[default: admin]${RESET}: " >/dev/tty
  read INPUT_USER </dev/tty
  INPUT_USER="${INPUT_USER:-admin}"
  if [[ "$INPUT_USER" =~ ^[a-zA-Z0-9_]{2,32}$ ]]; then
    PANEL_USER="$INPUT_USER"
    break
  else
    echo -e "  ${RED}✗ Username must be 2–32 characters, letters/numbers/underscore only.${RESET}"
  fi
done

# Password
while true; do
  echo -en "  ${BOLD}Password${RESET} ${DIM}(min 8 chars)${RESET}: " >/dev/tty
  read -s INPUT_PASS </dev/tty
  echo ""
  if [ ${#INPUT_PASS} -lt 8 ]; then
    echo -e "  ${RED}✗ Password must be at least 8 characters.${RESET}"
    continue
  fi
  echo -en "  ${BOLD}Confirm password${RESET}: " >/dev/tty
  read -s INPUT_PASS2 </dev/tty
  echo ""
  if [ "$INPUT_PASS" != "$INPUT_PASS2" ]; then
    echo -e "  ${RED}✗ Passwords do not match. Try again.${RESET}"
    continue
  fi
  PANEL_PASS="$INPUT_PASS"
  break
done

echo ""

# ── Detect public IP ────────────────────────────────────────────
info "Detecting public IP..."
PUBLIC_IP=""
for svc in \
  "https://api.ipify.org" \
  "https://ifconfig.me/ip" \
  "https://icanhazip.com" \
  "https://checkip.amazonaws.com"; do
  PUBLIC_IP=$(curl -s --connect-timeout 5 --max-time 8 "$svc" 2>/dev/null | tr -d '[:space:]') || true
  if [[ "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    break
  fi
  PUBLIC_IP=""
done

# Fallback to local IP
if [ -z "$PUBLIC_IP" ]; then
  PUBLIC_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  warn "Could not detect public IP. Using local IP: ${PUBLIC_IP}"
fi

[ -z "$PUBLIC_IP" ] && die "Cannot determine IP address. Check your network connection."

SSLIP_DOMAIN="${PUBLIC_IP//./-}.sslip.io"
PANEL_URL="https://${SSLIP_DOMAIN}"

echo ""
echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}Installation Summary${RESET}"
echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"
echo -e "  ${DIM}Public IP :${RESET} ${BOLD}${PUBLIC_IP}${RESET}"
echo -e "  ${DIM}Panel URL :${RESET} ${BOLD}${PANEL_URL}${RESET}"
echo -e "  ${DIM}Username  :${RESET} ${BOLD}${PANEL_USER}${RESET}"
echo -e "  ${DIM}Password  :${RESET} ${BOLD}[hidden]${RESET}"
echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"
echo ""

echo -en "  Continue installation? ${DIM}[Y/n]${RESET}: " >/dev/tty
read CONFIRM </dev/tty
CONFIRM="${CONFIRM:-Y}"
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && echo -e "\n  ${YELLOW}Installation cancelled.${RESET}\n" && exit 0
echo ""

# ── Step 1: System packages ─────────────────────────────────────
step 1 "Updating package lists..."
apt-get update -qq || die "apt-get update failed. Check internet connection."

step 2 "Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  python3 python3-pip curl \
  debian-keyring debian-archive-keyring apt-transport-https \
  || die "Failed to install system packages."

step 3 "Installing Flask..."
# Prefer apt package — avoids pip/system conflicts on Ubuntu 22/24
if apt-get install -y -qq python3-flask 2>/dev/null; then
  : # installed via apt
elif pip3 install flask --break-system-packages -q 2>/dev/null; then
  : # installed via pip with override
elif pip3 install flask -q 2>/dev/null; then
  : # installed via pip fallback
else
  die "Failed to install Flask. Try manually: apt install python3-flask"
fi

# ── Step 2: Install Caddy ───────────────────────────────────────
step 4 "Installing Caddy (reverse proxy + HTTPS)..."

if ! command -v caddy &>/dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null \
    || die "Failed to import Caddy GPG key."

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null \
    || die "Failed to add Caddy repository."

  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq caddy \
    || die "Failed to install Caddy."
fi

# ── Step 3: Write Flask app ─────────────────────────────────────
step 5 "Deploying panel application..."
mkdir -p /opt/hypersnap-panel

cat > /opt/hypersnap-panel/app.py << 'PYEOF'
from flask import Flask, request, Response, render_template_string
import urllib.request, json, functools, os, datetime, hashlib, hmac

app = Flask(__name__)

USERNAME = os.environ.get("PANEL_USER", "admin")
PASSWORD_HASH = os.environ.get("PANEL_PASS_HASH", "")
NODE_PORT = int(os.environ.get("NODE_PORT", "3381"))

def check_auth(u, p):
    if u != USERNAME:
        return False
    p_hash = hashlib.sha256(p.encode()).hexdigest()
    return hmac.compare_digest(p_hash, PASSWORD_HASH)

def require_auth(f):
    @functools.wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return Response(
                "Unauthorized", 401,
                {"WWW-Authenticate": 'Basic realm="Hypersnap Panel"',
                 "Cache-Control": "no-store"}
            )
        return f(*args, **kwargs)
    return decorated

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<meta name="theme-color" content="#050507">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<title>Hypersnap — Node Monitor</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
<style>
:root {
  --bg:       #050507;
  --bg2:      #09090f;
  --surface:  #0e0e18;
  --surface2: #13131f;
  --border:   rgba(255,255,255,0.06);
  --border2:  rgba(255,255,255,0.10);
  --glow:     #00ffc8;
  --glow2:    #6c63ff;
  --warn:     #ffb347;
  --danger:   #ff5f5f;
  --text:     #e6e6f0;
  --muted:    #5a5a78;
  --mono:     'Space Mono', monospace;
  --sans:     'Outfit', sans-serif;
  --r:        14px;
  --r-sm:     8px;
  --safe-bottom: env(safe-area-inset-bottom, 0px);
}
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html { background: var(--bg); scroll-behavior: smooth; }

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--sans);
  min-height: 100vh;
  overflow-x: hidden;
  -webkit-font-smoothing: antialiased;
}

/* Background grid */
body::before {
  content: '';
  position: fixed; inset: 0;
  background-image:
    linear-gradient(rgba(0,255,200,.025) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,255,200,.025) 1px, transparent 1px);
  background-size: 48px 48px;
  pointer-events: none; z-index: 0;
}

/* Ambient glow blobs */
body::after {
  content: '';
  position: fixed;
  top: -20vh; left: -20vw;
  width: 60vw; height: 60vh;
  background: radial-gradient(ellipse, rgba(108,99,255,.06) 0%, transparent 70%);
  pointer-events: none; z-index: 0;
}

.glow-blob-2 {
  position: fixed;
  bottom: -15vh; right: -15vw;
  width: 50vw; height: 50vh;
  background: radial-gradient(ellipse, rgba(0,255,200,.05) 0%, transparent 70%);
  pointer-events: none; z-index: 0;
}

/* ── Layout ── */
.wrap {
  position: relative; z-index: 1;
  max-width: 1100px;
  margin: 0 auto;
  padding: 0 20px calc(32px + var(--safe-bottom)) 20px;
}

/* ── Header ── */
header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 24px 0 28px;
  border-bottom: 1px solid var(--border);
  margin-bottom: 28px;
  flex-wrap: wrap;
  gap: 16px;
}

.logo {
  display: flex;
  align-items: center;
  gap: 12px;
}

.logo-icon {
  width: 40px; height: 40px;
  border: 1.5px solid var(--glow);
  border-radius: 10px;
  display: flex; align-items: center; justify-content: center;
  font-size: 20px;
  background: rgba(0,255,200,.05);
  box-shadow: 0 0 20px rgba(0,255,200,.15), inset 0 0 12px rgba(0,255,200,.05);
  flex-shrink: 0;
}

.logo-info { display: flex; flex-direction: column; gap: 2px; }

.logo-name {
  font-family: var(--sans);
  font-weight: 800;
  font-size: 1.05rem;
  letter-spacing: .02em;
}

.logo-sub {
  font-family: var(--mono);
  font-size: .58rem;
  color: var(--muted);
  letter-spacing: .18em;
  text-transform: uppercase;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.status-pill {
  display: flex; align-items: center; gap: 7px;
  background: var(--surface);
  border: 1px solid var(--border2);
  border-radius: 100px;
  padding: 6px 14px;
  font-family: var(--mono);
  font-size: .62rem;
  letter-spacing: .1em;
  text-transform: uppercase;
  white-space: nowrap;
}

.status-pill .dot {
  width: 6px; height: 6px;
  border-radius: 50%;
  background: var(--glow);
  box-shadow: 0 0 8px var(--glow);
  animation: breathe 2.5s ease-in-out infinite;
  flex-shrink: 0;
}
.status-pill.offline .dot {
  background: var(--danger);
  box-shadow: 0 0 8px var(--danger);
  animation: none;
}

@keyframes breathe {
  0%,100% { opacity:1; transform:scale(1); }
  50%      { opacity:.4; transform:scale(.75); }
}

.timestamp {
  font-family: var(--mono);
  font-size: .6rem;
  color: var(--muted);
  white-space: nowrap;
}

/* ── Section label ── */
.section-label {
  font-family: var(--mono);
  font-size: .6rem;
  letter-spacing: .22em;
  text-transform: uppercase;
  color: var(--muted);
  margin-bottom: 12px;
  display: flex; align-items: center; gap: 12px;
}
.section-label::after {
  content: '';
  flex: 1; height: 1px;
  background: var(--border);
}

/* ── Stat cards ── */
.cards-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  margin-bottom: 24px;
}

@media (max-width: 800px) { .cards-grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 420px) { .cards-grid { grid-template-columns: 1fr 1fr; gap: 10px; } }

.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 18px 16px;
  position: relative; overflow: hidden;
  transition: border-color .2s, transform .15s;
  cursor: default;
}
.card::before {
  content: '';
  position: absolute; top: 0; left: 0; right: 0;
  height: 1.5px;
  background: linear-gradient(90deg, transparent, var(--glow), transparent);
  opacity: 0;
  transition: opacity .25s;
}
.card:hover { border-color: var(--border2); transform: translateY(-1px); }
.card:hover::before { opacity: 1; }

.card-icon {
  font-size: 1rem;
  margin-bottom: 10px;
  opacity: .55;
}
.card-label {
  font-family: var(--mono);
  font-size: .58rem;
  letter-spacing: .15em;
  text-transform: uppercase;
  color: var(--muted);
  margin-bottom: 6px;
}
.card-value {
  font-family: var(--sans);
  font-size: 1.75rem;
  font-weight: 800;
  line-height: 1;
  letter-spacing: -.02em;
}
.card-value.sm { font-size: 1.2rem; }
.card-sub {
  font-family: var(--mono);
  font-size: .6rem;
  color: var(--muted);
  margin-top: 5px;
}
.color-glow   { color: var(--glow); }
.color-warn   { color: var(--warn); }
.color-danger { color: var(--danger); }

/* ── Table ── */
.table-section { margin-bottom: 24px; }
.table-wrap {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  overflow: hidden;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
table { width: 100%; border-collapse: collapse; min-width: 420px; }
thead th {
  font-family: var(--mono);
  font-size: .58rem;
  letter-spacing: .18em;
  text-transform: uppercase;
  color: var(--muted);
  padding: 12px 16px;
  text-align: left;
  background: rgba(255,255,255,.02);
  border-bottom: 1px solid var(--border);
  white-space: nowrap;
}
tbody tr {
  border-bottom: 1px solid var(--border);
  transition: background .15s;
}
tbody tr:last-child { border-bottom: none; }
tbody tr:hover { background: rgba(255,255,255,.025); }
td {
  padding: 13px 16px;
  font-family: var(--sans);
  font-size: .85rem;
  vertical-align: middle;
}
td .mono { font-family: var(--mono); font-size: .75rem; }

/* ── Badge ── */
.badge {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 3px 10px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: .62rem;
  font-weight: 700;
  letter-spacing: .06em;
  white-space: nowrap;
}
.badge::before { content: '●'; font-size: .45rem; }
.badge.ok     { background: rgba(0,255,200,.08); color: var(--glow);   border: 1px solid rgba(0,255,200,.2); }
.badge.warn   { background: rgba(255,179,71,.08); color: var(--warn);  border: 1px solid rgba(255,179,71,.2); }
.badge.danger { background: rgba(255,95,95,.08);  color: var(--danger); border: 1px solid rgba(255,95,95,.2); }

/* ── Peer block ── */
.peer-section { margin-bottom: 24px; }
.peer-box {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 16px 18px;
}
.peer-id {
  font-family: var(--mono);
  font-size: .72rem;
  color: var(--glow2);
  word-break: break-all;
  line-height: 1.65;
}
.peer-label {
  font-family: var(--mono);
  font-size: .6rem;
  letter-spacing: .15em;
  text-transform: uppercase;
  color: var(--muted);
  margin-bottom: 8px;
}

/* ── Raw JSON ── */
.raw-section { margin-bottom: 24px; }
details { width: 100%; }
details summary {
  cursor: pointer;
  font-family: var(--mono);
  font-size: .6rem;
  letter-spacing: .22em;
  text-transform: uppercase;
  color: var(--muted);
  margin-bottom: 12px;
  display: flex; align-items: center; gap: 12px;
  list-style: none; user-select: none;
  transition: color .2s;
}
details summary::-webkit-details-marker { display: none; }
details summary:hover { color: var(--text); }
details summary::before { content: '▶'; font-size: .5rem; transition: transform .2s; }
details[open] summary::before { transform: rotate(90deg); }
details summary::after { content: ''; flex: 1; height: 1px; background: var(--border); }

.json-box {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--r);
  padding: 16px 18px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
.json-box pre {
  font-family: var(--mono);
  font-size: .68rem;
  color: var(--muted);
  white-space: pre-wrap;
  word-break: break-all;
  line-height: 1.75;
}

/* ── Error state ── */
.error-box {
  background: rgba(255,95,95,.04);
  border: 1px solid rgba(255,95,95,.2);
  border-radius: var(--r);
  padding: 36px 24px;
  text-align: center;
  margin-bottom: 24px;
}
.error-icon { font-size: 2rem; margin-bottom: 14px; }
.error-title {
  font-family: var(--sans);
  font-weight: 700;
  font-size: 1.05rem;
  color: var(--danger);
  margin-bottom: 8px;
}
.error-msg {
  font-family: var(--mono);
  font-size: .7rem;
  color: var(--muted);
  margin-top: 8px;
  word-break: break-all;
}
.error-hint {
  font-size: .8rem;
  color: var(--muted);
  margin-top: 14px;
}
code {
  background: rgba(255,255,255,.06);
  border: 1px solid var(--border);
  padding: 2px 7px;
  border-radius: 4px;
  font-family: var(--mono);
  font-size: .8em;
}

/* ── Footer ── */
footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 20px;
  border-top: 1px solid var(--border);
  gap: 12px;
  flex-wrap: wrap;
}
.footer-left {
  font-family: var(--mono);
  font-size: .62rem;
  color: var(--muted);
  display: flex; align-items: center; gap: 10px;
  flex-wrap: wrap;
}
.countdown-badge {
  background: var(--surface2);
  border: 1px solid var(--border);
  border-radius: 100px;
  padding: 4px 12px;
  font-family: var(--mono);
  font-size: .6rem;
  color: var(--muted);
  white-space: nowrap;
}
.refresh-btn {
  background: rgba(0,255,200,.08);
  border: 1px solid rgba(0,255,200,.25);
  border-radius: var(--r-sm);
  padding: 8px 16px;
  color: var(--glow);
  font-family: var(--mono);
  font-size: .65rem;
  letter-spacing: .08em;
  cursor: pointer;
  transition: background .2s, border-color .2s, transform .1s;
  white-space: nowrap;
  -webkit-tap-highlight-color: transparent;
}
.refresh-btn:hover { background: rgba(0,255,200,.14); border-color: rgba(0,255,200,.4); }
.refresh-btn:active { transform: scale(.97); }

/* ── Loading skeleton ── */
.skeleton {
  background: linear-gradient(90deg, var(--surface) 25%, var(--surface2) 50%, var(--surface) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: 6px;
  height: 1em; width: 60%;
}
@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

/* ── Mobile tweaks ── */
@media (max-width: 600px) {
  .wrap { padding: 0 14px calc(20px + var(--safe-bottom)) 14px; }
  header { padding: 18px 0 20px; margin-bottom: 20px; }
  .logo-name { font-size: .95rem; }
  .timestamp { display: none; }
  .card { padding: 14px 12px; }
  .card-value { font-size: 1.45rem; }
  .card-value.sm { font-size: 1.05rem; }
  footer { padding-top: 16px; }
  .footer-left span:not(.countdown-badge) { display: none; }
}
@media (max-width: 360px) {
  .cards-grid { grid-template-columns: 1fr 1fr; gap: 8px; }
  .card { padding: 12px 10px; }
}
</style>
</head>
<body>
<div class="glow-blob-2"></div>
<div class="wrap">

  <header>
    <div class="logo">
      <div class="logo-icon">⬡</div>
      <div class="logo-info">
        <div class="logo-name">Hypersnap</div>
        <div class="logo-sub">Node Monitor</div>
      </div>
    </div>
    <div class="header-right">
      <div class="timestamp">{{ now }}</div>
      {% if error %}
        <div class="status-pill offline"><div class="dot"></div>Offline</div>
      {% else %}
        <div class="status-pill"><div class="dot"></div>Online</div>
      {% endif %}
    </div>
  </header>

  {% if error %}
  <div class="error-box">
    <div class="error-icon">⚡</div>
    <div class="error-title">Cannot reach node</div>
    <div class="error-hint">No response from <code>127.0.0.1:3381</code></div>
    <div class="error-msg">{{ error }}</div>
  </div>

  {% else %}

  <div class="section-label">Overview</div>
  <div class="cards-grid">
    <div class="card">
      <div class="card-icon">🔖</div>
      <div class="card-label">Version</div>
      <div class="card-value sm color-glow">{{ info.version or '—' }}</div>
    </div>
    <div class="card">
      <div class="card-icon">📦</div>
      <div class="card-label">Shards</div>
      <div class="card-value">{{ (info.shardInfos or []) | length }}</div>
    </div>
    <div class="card">
      <div class="card-icon">📡</div>
      <div class="card-label">Peers</div>
      <div class="card-value">{{ info.numPeers if info.numPeers is defined else '—' }}</div>
    </div>
    <div class="card">
      <div class="card-icon">🔄</div>
      <div class="card-label">Sync</div>
      {% set ns = namespace(td=0) %}
      {% for s in info.shardInfos or [] %}{% set ns.td = ns.td + s.blockDelay %}{% endfor %}
      {% set cnt = [(info.shardInfos or [{}]) | length, 1] | max %}
      {% set avg = (ns.td / cnt) | int %}
      {% if avg < 20 %}
        <div class="card-value sm color-glow">Synced</div>
        <div class="card-sub">avg delay {{ avg }}</div>
      {% elif avg < 2000 %}
        <div class="card-value sm color-warn">Syncing</div>
        <div class="card-sub">avg delay {{ avg }}</div>
      {% else %}
        <div class="card-value sm color-danger">Behind</div>
        <div class="card-sub">avg delay {{ avg }}</div>
      {% endif %}
    </div>
  </div>

  {% if info.shardInfos %}
  <div class="table-section">
    <div class="section-label">Shard Details</div>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Shard ID</th>
            <th>Max Height</th>
            <th>Block Delay</th>
            <th>Health</th>
          </tr>
        </thead>
        <tbody>
          {% for s in info.shardInfos %}
          <tr>
            <td><span class="mono">{{ s.shardId }}</span></td>
            <td>{{ "{:,}".format(s.maxHeight) }}</td>
            <td><span class="mono">{{ s.blockDelay }}</span></td>
            <td>
              {% if s.blockDelay < 20 %}<span class="badge ok">Healthy</span>
              {% elif s.blockDelay < 2000 %}<span class="badge warn">Syncing</span>
              {% else %}<span class="badge danger">Behind</span>{% endif %}
            </td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </div>
  {% endif %}

  {% if info.peer_id %}
  <div class="peer-section">
    <div class="section-label">Peer Identity</div>
    <div class="peer-box">
      <div class="peer-label">Peer ID</div>
      <div class="peer-id">{{ info.peer_id }}</div>
    </div>
  </div>
  {% endif %}

  <div class="raw-section">
    <details>
      <summary>Raw Node Data</summary>
      <div class="json-box"><pre>{{ raw }}</pre></div>
    </details>
  </div>
  {% endif %}

  <footer>
    <div class="footer-left">
      <span>Hypersnap Node Monitor</span>
      <span class="countdown-badge">Refresh in <span id="cd">30</span>s</span>
    </div>
    <button class="refresh-btn" onclick="location.reload()">↻ Refresh</button>
  </footer>

</div>
<script>
(function() {
  var t = 30;
  var el = document.getElementById('cd');
  var iv = setInterval(function() {
    t--;
    if (el) el.textContent = t;
    if (t <= 0) { clearInterval(iv); location.reload(); }
  }, 1000);
})();
</script>
</body>
</html>"""

@app.route("/")
@require_auth
def index():
    try:
        req = urllib.request.Request(
            f"http://127.0.0.1:{NODE_PORT}/v1/info",
            headers={"User-Agent": "HypersnapPanel/2.0"}
        )
        with urllib.request.urlopen(req, timeout=5) as r:
            data = json.loads(r.read())
        raw = json.dumps(data, indent=2)
        now = datetime.datetime.utcnow().strftime("UTC %Y-%m-%d  %H:%M:%S")
        return render_template_string(HTML, info=data, raw=raw, error=None, now=now)
    except Exception as e:
        now = datetime.datetime.utcnow().strftime("UTC %Y-%m-%d  %H:%M:%S")
        return render_template_string(HTML, info={}, raw="", error=str(e), now=now)

@app.route("/health")
def health():
    return {"status": "ok"}, 200

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
PYEOF

chmod 644 /opt/hypersnap-panel/app.py

# Hash the password for secure storage (never store plaintext)
# Read from stdin to safely handle special characters in passwords
PASS_HASH=$(printf '%s' "${PANEL_PASS}" | python3 -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())")

# ── Step 4: systemd service ─────────────────────────────────────
step 6 "Configuring services..."

cat > /etc/systemd/system/hypersnap-panel.service << EOF
[Unit]
Description=Hypersnap Node Panel (Flask)
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=/opt/hypersnap-panel
Environment="PANEL_USER=${PANEL_USER}"
Environment="PANEL_PASS_HASH=${PASS_HASH}"
Environment="NODE_PORT=3381"
ExecStart=/usr/bin/python3 /opt/hypersnap-panel/app.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

chmod 600 /etc/systemd/system/hypersnap-panel.service

# ── Caddy config ────────────────────────────────────────────────
cat > /etc/caddy/Caddyfile << EOF
${SSLIP_DOMAIN} {
    reverse_proxy 127.0.0.1:5000

    # Security headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        -Server
    }

    log {
        output discard
    }
}
EOF

# ── Start services ───────────────────────────────────────────────
systemctl daemon-reload
systemctl enable hypersnap-panel --quiet
systemctl restart hypersnap-panel

systemctl enable caddy --quiet
systemctl restart caddy

# ── Firewall ─────────────────────────────────────────────────────
if command -v ufw &>/dev/null; then
  ufw allow 80/tcp  &>/dev/null || true
  ufw allow 443/tcp &>/dev/null || true
  # Block direct access to Flask (only via Caddy)
  ufw deny 5000     &>/dev/null || true
fi

# ── Health check ─────────────────────────────────────────────────
sleep 3
FLASK_STATUS=$(systemctl is-active hypersnap-panel 2>/dev/null || echo "unknown")
CADDY_STATUS=$(systemctl is-active caddy 2>/dev/null || echo "unknown")

echo ""
echo -e "  ${CYAN}──────────────────────────────────────────────────${RESET}"

if [ "$FLASK_STATUS" = "active" ] && [ "$CADDY_STATUS" = "active" ]; then
  echo -e "  ${GREEN}${BOLD}✓  Installation complete!${RESET}"
else
  warn "One or more services may not be running correctly."
  [ "$FLASK_STATUS" != "active" ] && echo -e "  ${RED}Flask:${RESET} ${FLASK_STATUS} — run: journalctl -u hypersnap-panel -n 30"
  [ "$CADDY_STATUS" != "active" ] && echo -e "  ${RED}Caddy:${RESET} ${CADDY_STATUS} — run: journalctl -u caddy -n 30"
fi

echo ""
echo -e "  ${CYAN}┌──────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  🔒  ${BOLD}${PANEL_URL}${RESET}"
echo -e "  ${CYAN}│${RESET}  👤  User: ${BOLD}${PANEL_USER}${RESET}"
echo -e "  ${CYAN}│${RESET}  🔑  Pass: ${BOLD}(the one you entered)${RESET}"
echo -e "  ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  Flask : ${FLASK_STATUS}    Caddy : ${CADDY_STATUS}"
echo -e "  ${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "  ${YELLOW}Note:${RESET} First visit may take ~30s for SSL certificate."
echo ""
echo -e "  ${DIM}Useful commands:${RESET}"
echo -e "  ${DIM}journalctl -u hypersnap-panel -f${RESET}"
echo -e "  ${DIM}journalctl -u caddy -f${RESET}"
echo -e "  ${DIM}systemctl restart hypersnap-panel${RESET}"
echo ""
