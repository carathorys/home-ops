#!/bin/sh
# Runs in a plain Alpine init container before gluetun on every pod start:
# exchanges the NordVPN access token for the NordLynx (WireGuard) private key
# via the NordVPN API and writes it to /run/secrets/wg0.conf (an in-memory
# volume), where gluetun reads it. Never prints the token or the key.
#
# gluetun's firewall is not up yet, so these calls (Alpine's package mirror,
# api.nordvpn.com) go out directly, resolved via the pod's 1.1.1.1 nameserver.
set -eu

: "${NORDVPN_ACCESS_TOKEN:?NORDVPN_ACCESS_TOKEN is not set}"

apk add --no-cache --quiet curl jq

if ! response="$(curl -fsS --retry 5 --retry-connrefused --retry-delay 3 --max-time 20 \
  -u "token:${NORDVPN_ACCESS_TOKEN}" \
  https://api.nordvpn.com/v1/users/services/credentials)"; then
  echo "NordVPN API request failed: is the access token expired or invalid?" >&2
  exit 1
fi

if ! key="$(printf '%s' "$response" | jq -er '.nordlynx_private_key // empty')"; then
  echo "The NordVPN API response contains no NordLynx private key" >&2
  exit 1
fi

umask 077
printf '[Interface]\nPrivateKey = %s\n' "$key" > /run/secrets/wg0.conf
echo "Wrote the NordLynx private key for gluetun"
