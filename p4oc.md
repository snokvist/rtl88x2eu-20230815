# P4OC Rate Adaptation (RA) Mode

## Purpose
P4OC is now intentionally **simple** and stability-focused:
- cap HT rates to `MCS0..N` (typically `N<=7`),
- run dynamic checks faster (10..50ms clamp when enabled),
- avoid unintended CCK fallback on non-CCK links.

## Proc control
Per-interface control file:

`/proc/net/<driver>/<iface>/p4oc_ra`

Write format:

```sh
# echo "<enable> [max_ht_mcs] [interval_ms]" > p4oc_ra
```

Examples:

```sh
# enable with defaults
echo "1" > /proc/net/<driver>/<iface>/p4oc_ra

# explicit cap + interval
echo "1 3 50" > /proc/net/<driver>/<iface>/p4oc_ra

# disable
echo "0" > /proc/net/<driver>/<iface>/p4oc_ra
```

Readback fields:
- `enable`
- `max_ht_mcs`
- `interval_ms`
- `effective_interval_ms`

## Bandwidth hint
Read-only telemetry:

`/proc/net/<driver>/<iface>/p4oc_bw_hint`

Key outputs:
- `tx_kbps`, `rx_kbps`, `app_hint_kbps` (moving average)
- `sample_interval_ms`, `poll_recommend_ms`
- `curr_mcs`, `curr_rate`, `curr_bw`, `curr_rssi`
- `theoretical_current_kbps`, `theoretical_allowed_kbps`
- `curr_ramask`

## Implementation note
Advanced mode/tuning path was removed. Remaining P4OC behavior reuses baseline RA flow plus:
- HT cap mask enforcement,
- non-CCK guard (`CCK` bits cleared when link mode has no CCK),
- fast dynamic-check interval control.
