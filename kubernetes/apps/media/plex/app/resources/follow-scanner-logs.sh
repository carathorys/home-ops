#!/bin/sh
# Follows Plex's three Media Scanner logs on stdout for Loki, as one source.
# Each line gets its file as a suffix, e.g. " [Matcher]", so the scanners stay
# distinguishable; the suffix keeps the line start intact for the otel-agent's
# Plex level mapping. tail -F follows the files across Plex's rotations.
cd /logs || exit 1
tail -n 0 -F \
  "Plex Media Scanner Matcher.log" \
  "Plex Media Scanner Analysis.log" \
  "Plex Media Scanner Chapter Thumbnails.log" 2>/dev/null |
  awk '
    /^==> .* <==$/ {
      source = $0
      sub(/^==> Plex Media Scanner /, "", source)
      sub(/\.log <==$/, "", source)
      next
    }
    NF {
      print $0 " [" source "]"
      fflush()
    }
  '
