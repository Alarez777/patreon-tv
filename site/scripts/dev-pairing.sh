#!/usr/bin/env bash
# Start the pairing portal for local dev on your LAN (iPhone / Apple TV can reach it).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The app reads its pairing origin from Info.plist, populated by the
# PAIRING_BASE_URL build setting in project.yml (Debug config).
TVOS_PROJECT_YML="$ROOT/../apps/tvos/project.yml"
PORT="${PAIRING_PORT:-8788}"

# Host LAN IP. Prefers explicit interface names (br0/bridge0 first, then the
# usual Wi‑Fi/Ethernet names), then falls back to the routing table, then
# `hostname -I`. macOS reads addresses with ipconfig; Linux with `ip`.
pick_ip() {
  local iface ip

  for iface in br0 bridge0 en0 en1 eth0 wlan0; do
    ip=""
    if command -v ipconfig >/dev/null 2>&1; then
      ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    fi
    if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
      ip="$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null \
        | awk '{ print $4 }' | cut -d/ -f1 | head -n1 || true)"
    fi
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  done

  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null \
      | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }' \
      || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi

  if command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{ print $1 }' || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi

  echo "Could not detect a LAN IP. Set PAIRING_LAN_IP manually." >&2
  exit 1
}

IP="${PAIRING_LAN_IP:-$(pick_ip)}"
ORIGIN="http://${IP}:${PORT}"

echo "Pairing LAN origin: ${ORIGIN}"
echo "QR / link URLs will use this address for devices on your Wi‑Fi."

cat > "$ROOT/.dev.vars" <<EOF
PAIRING_PUBLIC_ORIGIN=${ORIGIN}
EOF

echo "Sign in on the link page by pasting your patreon.com session_id cookie."

if [[ -f "$TVOS_PROJECT_YML" ]]; then
  # Point the app's Debug pairing origin at this LAN IP for the dev session,
  # and restore the tracked file when the server stops so the working tree
  # isn't left dirty with a local IP. Re-run `xcodegen generate` after this
  # script changes the value (and again after it restores it).
  cp "$TVOS_PROJECT_YML" "${TVOS_PROJECT_YML}.bak"
  trap 'if [[ -f "${TVOS_PROJECT_YML}.bak" ]]; then mv "${TVOS_PROJECT_YML}.bak" "$TVOS_PROJECT_YML"; echo "Restored ${TVOS_PROJECT_YML}"; fi' EXIT
  # Portable in-place edit (no perl, no GNU/BSD `sed -i` difference).
  # Only the value under the `Debug:` config, matching the comment above.
  tmp="$TVOS_PROJECT_YML.tmp.$$"
  sed "/^[[:space:]]*Debug:/{ n; s#PAIRING_BASE_URL: [^[:space:]]*#PAIRING_BASE_URL: ${ORIGIN}#; }" \
    "$TVOS_PROJECT_YML" > "$tmp"
  mv "$tmp" "$TVOS_PROJECT_YML"
  echo "Updated ${TVOS_PROJECT_YML} Debug PAIRING_BASE_URL → ${ORIGIN} (restored on exit)"
fi

cd "$ROOT"
npm run build
npx wrangler pages dev dist --port "$PORT" --ip 0.0.0.0
