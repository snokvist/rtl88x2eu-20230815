#!/bin/sh
# Busybox-friendly P4OC RA config helper
# Usage:
#   p4oc_ra_config.sh <iface> [enable] [max_ht_mcs] [interval_ms] [rssi_th_ofst]

IFACE="$1"
EN="${2:-1}"
MAXMCS="${3:-7}"
INTV="${4:-20}"
RTHO="${5:-0}"

if [ -z "$IFACE" ]; then
  echo "usage: $0 <iface> [enable] [max_ht_mcs] [interval_ms] [rssi_th_ofst]" >&2
  exit 1
fi

BASE="/proc/net"
PFILE=""

for d in "$BASE"/*; do
  [ -d "$d" ] || continue
  if [ -e "$d/$IFACE/p4oc_ra" ]; then
    PFILE="$d/$IFACE/p4oc_ra"
    break
  fi
done

if [ -z "$PFILE" ]; then
  echo "p4oc_ra proc not found for iface=$IFACE" >&2
  exit 2
fi

echo "$EN $MAXMCS $INTV $RTHO" > "$PFILE" || exit 3
echo "configured: $(cat "$PFILE")"
