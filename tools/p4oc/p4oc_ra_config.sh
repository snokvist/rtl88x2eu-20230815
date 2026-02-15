#!/bin/sh
# Busybox-friendly P4OC RA config helper
# Usage:
#   p4oc_ra_config.sh <iface> [enable] [max_ht_mcs] [interval_ms] [up_hysteresis] [probe_step] [retry_hi] [retry_low] [cooldown_hi] [cooldown_low]

IFACE="$1"
EN="${2:-1}"
MAXMCS="${3:-7}"
INTV="${4:-20}"
HYST="${5:-3}"
PSTEP="${6:-2}"
RHI="${7:-45}"
RLO="${8:-30}"
CHI="${9:-3}"
CLO="${10:-2}"

if [ -z "$IFACE" ]; then
  echo "usage: $0 <iface> [enable] [max_ht_mcs] [interval_ms] [up_hysteresis] [probe_step] [retry_hi] [retry_low] [cooldown_hi] [cooldown_low]" >&2
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

echo "$EN $MAXMCS $INTV $HYST $PSTEP $RHI $RLO $CHI $CLO" > "$PFILE" || exit 3
echo "configured: $(cat "$PFILE")"
