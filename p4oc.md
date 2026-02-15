# P4OC Rate Adaptation (RA) Mode

## Purpose
P4OC is intentionally simple and stability-focused:
- cap HT rates to `MCS0..N` (typically `N<=7`),
- run dynamic checks faster (10..50ms clamp when enabled),
- avoid unintended CCK fallback on non-CCK links,
- optionally shift RSSI thresholds via a single signed offset.

## Proc control
Per-interface control file:

`/proc/net/<driver>/<iface>/p4oc_ra`

Write format:

```sh
# echo "<enable> [max_ht_mcs] [interval_ms] [rssi_th_ofst]" > p4oc_ra
```

Examples:

```sh
# enable with defaults
echo "1" > /proc/net/<driver>/<iface>/p4oc_ra

# explicit cap + interval + rssi threshold offset
echo "1 3 50 -4" > /proc/net/<driver>/<iface>/p4oc_ra

# disable
echo "0" > /proc/net/<driver>/<iface>/p4oc_ra
```

Readback fields:
- `enable`
- `max_ht_mcs`
- `interval_ms`
- `rssi_th_offset`
- `effective_interval_ms`

`rssi_th_offset` is clamped to `[-30, 30]` and shifts PHYDM RSSI floor thresholds:
- negative -> more conservative (earlier downshift),
- positive -> more aggressive (later downshift).

## Bandwidth hint
Read-only telemetry: `/proc/net/<driver>/<iface>/p4oc_bw_hint`


## Troubleshooting `ra_config.sh`

`tools/p4oc/p4oc_ra_config.sh` now writes then re-reads `p4oc_ra` and exits non-zero if requested values are not applied.
This helps catch cases where manual config appears to do nothing.
