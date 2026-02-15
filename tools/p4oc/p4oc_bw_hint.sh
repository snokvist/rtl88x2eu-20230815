#!/bin/sh
# Busybox-friendly helper for streamer apps to read bandwidth hint
# Usage: p4oc_bw_hint.sh <iface>

IFACE="$1"
[ -n "$IFACE" ] || { echo "usage: $0 <iface>" >&2; exit 1; }

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

BWHINT="$(find_proc_file p4oc_bw_hint)" || { echo "missing p4oc_bw_hint" >&2; exit 2; }

cat "$BWHINT"
