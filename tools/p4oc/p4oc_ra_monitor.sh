#!/bin/sh
# Busybox-friendly monitor loop for manual RF testing
# Usage: p4oc_ra_monitor.sh <iface> [seconds]

IFACE="$1"
SECS="${2:-30}"
[ -n "$IFACE" ] || { echo "usage: $0 <iface> [seconds]" >&2; exit 1; }

find_proc_file() {
  for d in /proc/net/*; do
    [ -d "$d" ] || continue
    if [ -e "$d/$IFACE/$1" ]; then
      echo "$d/$IFACE/$1"
      return 0
    fi
  done
  return 1
}

P4OC="$(find_proc_file p4oc_ra)" || { echo "missing p4oc_ra" >&2; exit 2; }
TXBMP="$(find_proc_file tx_rate_bmp)"

i=0
while [ "$i" -lt "$SECS" ]; do
  echo "=== t=$i ==="
  cat "$P4OC"
  if [ -n "$TXBMP" ]; then
    echo "--- tx_rate_bmp ---"
    cat "$TXBMP"
  fi
  sleep 1
  i=$((i+1))
done
