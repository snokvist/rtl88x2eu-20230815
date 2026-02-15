# P4OC RA Plan (Simplified)

## Goal
Provide a deterministic link-survival mode with minimal knobs.

## Implemented approach
1. Proc control: `p4oc_ra` with
   - `enable`
   - `max_ht_mcs`
   - `interval_ms`
   - `rssi_th_ofst`
2. PHYDM behavior when enabled:
   - apply HT cap mask,
   - strip CCK bits on non-CCK wireless modes,
   - apply RSSI threshold offset in `phydm_rssi_lv_dec()`.
3. Dynamic check interval:
   - clamped to 10..50ms while enabled.

## Verification points
- `cat /proc/net/<driver>/<iface>/p4oc_ra` reflects requested values.
- `effective_interval_ms` in [10..50] while enabled.
- On capped configs, observed TX MCS does not exceed cap.
- RSSI offset tuning changes rate-level transition sensitivity as expected.
