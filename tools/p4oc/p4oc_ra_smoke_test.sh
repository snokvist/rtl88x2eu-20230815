#!/bin/sh
# Busybox-friendly smoke test for P4OC RA proc integration
# Usage: p4oc_ra_smoke_test.sh <iface>

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

P4OC="$(find_proc_file p4oc_ra)" || { echo "missing p4oc_ra" >&2; exit 2; }
TXBMP="$(find_proc_file tx_rate_bmp)"

echo "[1] write/read p4oc_ra"
echo "1 7 20 3 2 45 30 3 2" > "$P4OC" || exit 3
cat "$P4OC" || exit 4

echo "[2] validate effective interval in [10..50]"
EFF="$(awk -F= '/effective_interval_ms/{print $2}' "$P4OC" | tr -d ' \r')"
case "$EFF" in
  '' ) echo "effective interval missing"; exit 5 ;;
  *[!0-9]* ) echo "effective interval not numeric: $EFF"; exit 6 ;;
esac
if [ "$EFF" -lt 10 ] || [ "$EFF" -gt 50 ]; then
  echo "effective interval out of range: $EFF"
  exit 7
fi

echo "[3] optional tx_rate_bmp capture"
if [ -n "$TXBMP" ]; then
  cat "$TXBMP"
else
  echo "tx_rate_bmp not found (non-fatal)"
fi

echo "smoke test: PASS"
