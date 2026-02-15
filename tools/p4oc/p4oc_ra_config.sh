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

PFILE="$(find_proc_file p4oc_ra)" || {
  echo "p4oc_ra proc not found for iface=$IFACE" >&2
  exit 2
}

# Keep compatibility if caller still passes old extra args; ignore silently after arg5.
echo "$EN $MAXMCS $INTV $RTHO" > "$PFILE" || exit 3

OUT="$(cat "$PFILE")" || exit 4
echo "$OUT"

# Verify that key fields actually applied; fail loudly if they didn't.
ACT_EN="$(echo "$OUT" | awk -F= '/^enable=/{print $2}' | tr -d ' ')"
ACT_MCS="$(echo "$OUT" | awk -F= '/^max_ht_mcs=/{print $2}' | tr -d ' ')"
ACT_INTV="$(echo "$OUT" | awk -F= '/^interval_ms=/{print $2}' | tr -d ' ')"
ACT_RTHO="$(echo "$OUT" | awk -F= '/^rssi_th_offset=/{print $2}' | tr -d ' ')"

[ -n "$ACT_EN" ] || { echo "apply check failed: missing enable" >&2; exit 5; }
[ -n "$ACT_MCS" ] || { echo "apply check failed: missing max_ht_mcs" >&2; exit 6; }
[ -n "$ACT_INTV" ] || { echo "apply check failed: missing interval_ms" >&2; exit 7; }
[ -n "$ACT_RTHO" ] || { echo "apply check failed: missing rssi_th_offset" >&2; exit 8; }

if [ "$ACT_EN" != "$EN" ] || [ "$ACT_MCS" != "$MAXMCS" ] || [ "$ACT_INTV" != "$INTV" ]; then
  echo "apply mismatch: requested=[$EN $MAXMCS $INTV $RTHO] got=[enable=$ACT_EN max_ht_mcs=$ACT_MCS interval_ms=$ACT_INTV rssi_th_offset=$ACT_RTHO]" >&2
  exit 9
fi

echo "configured: enable=$ACT_EN max_ht_mcs=$ACT_MCS interval_ms=$ACT_INTV rssi_th_offset=$ACT_RTHO"
