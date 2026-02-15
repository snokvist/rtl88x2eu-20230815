# P4OC RA Plan (Simplified)

## Goal
Provide a practical, deterministic link-survival mode with minimal knobs.

## Implemented approach
1. Proc control: `p4oc_ra` with only
   - `enable`
   - `max_ht_mcs`
   - `interval_ms`
2. PHYDM mask behavior when enabled:
   - apply HT cap mask,
   - strip CCK bits on non-CCK wireless modes.
3. Dynamic check interval:
   - clamped to 10..50ms while enabled (legacy behavior when disabled).

## Why simplified
The earlier advanced path (extra retry/cooldown/hysteresis tuning) was too hard to validate reliably in field conditions.

## Verification points
- `cat /proc/net/<driver>/<iface>/p4oc_ra` reflects requested values.
- `effective_interval_ms` in [10..50] while enabled.
- On capped configs, observed TX MCS does not exceed cap.
- On non-CCK links (e.g. 5GHz), avoid CCK fallback; verify via `curr_rate` and `curr_ramask` in `p4oc_bw_hint`.
