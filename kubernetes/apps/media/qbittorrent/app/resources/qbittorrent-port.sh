#!/bin/sh
# Called by gluetun when VPN port forwarding goes up or down
# (VPN_PORT_FORWARDING_UP_COMMAND / _DOWN_COMMAND):
#   up <port> <interface>  -> qBittorrent listens on Proton's forwarded port,
#                             bound to the VPN interface (active mode)
#   down                   -> listening port 0 on "lo": no torrent traffic
#                             until the forwarding is back (qBittorrent also
#                             needs the port re-set after a reconnect)
# Uses qBittorrent's WebUI API on localhost, which needs "Bypass
# authentication for clients on localhost" enabled in qBittorrent.
# gluetun can run this before qBittorrent is up, so it retries for 5 minutes.
set -eu

api=http://127.0.0.1:8080/api/v2/app/setPreferences

case "${1:-}" in
  up)
    port="${2:?port missing}"
    iface="${3:-tun0}"
    json="{\"listen_port\":${port},\"current_network_interface\":\"${iface}\",\"random_port\":false,\"upnp\":false}"
    ;;
  down)
    port=0
    iface=lo
    json='{"listen_port":0,"current_network_interface":"lo"}'
    ;;
  *)
    echo "usage: $0 up <port> <interface> | down" >&2
    exit 2
    ;;
esac

for attempt in $(seq 1 60); do
  if wget -q -O /dev/null -T 5 --post-data "json=${json}" "$api"; then
    echo "qBittorrent: listening port ${port}, interface ${iface} ($1)"
    exit 0
  fi
  [ "$attempt" -eq 60 ] || sleep 5
done
echo "qBittorrent WebUI did not accept the settings: is 'Bypass authentication for clients on localhost' enabled?" >&2
exit 1
