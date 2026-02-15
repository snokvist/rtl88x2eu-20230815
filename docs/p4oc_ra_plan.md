# P4OC RA Stability Mode Plan and Implementation Notes

## Goal
Provide a runtime mode that prioritizes link survival over peak throughput by:
- Capping HT rates to MCS0..7 (HT20/HT40).
- Driving faster RA updates (10-50 ms) when enabled.
- Adding conservative rate-up hysteresis.

## Control Interface
A new proc entry is added:

`/proc/net/<driver>/<iface>/p4oc_ra`

Format:

`echo "<enable> [max_ht_mcs] [interval_ms] [up_hysteresis] [probe_step] [retry_hi] [retry_low] [cooldown_hi] [cooldown_low]" > p4oc_ra`

Examples:
- `echo "1" > p4oc_ra` : enable defaults.
- `echo "1 7 20 3 2" > p4oc_ra` : enable with explicit values.
- `echo "0" > p4oc_ra` : disable.

Read back:

`cat p4oc_ra`

## Behavior
1. **Rate cap**
   - In P4OC mode the PHYDM RA mask is further constrained to legacy + HT MCS0..N.
   - For the requested mode use `max_ht_mcs=7`.
2. **Faster adaptation**
   - Dynamic check timer interval switches from 2000 ms to clamped `[10..50]` ms.
3. **Conservative rate-up**
   - Probe-step cap limits upward envelope to `current_mcs + probe_step` (bounded by max cap).
   - If a newly computed RA mask enables additional rates versus current mask,
     that rate-up is delayed until `up_hysteresis` consecutive cycles pass.
4. **Retry-sensitive rate-down**
   - FW retry ratio (`curr_retry_ratio`) biases downward by +1/+2 RSSI levels at thresholds.
   - Rate-down remains immediate.

## Verification Points
1. `p4oc_ra` readback shows requested values.
2. Effective interval shown by `p4oc_ra` is within 10..50 ms when enabled.
3. `tx_rate_bmp` and/or station rate output never shows HT MCS above configured cap.
4. Link under degraded RF should show fast downshift and slower upshift.

5. `p4oc_bw_hint` provides a conservative app-level bandwidth hint for adaptive streamers.

## Current Scope
Implemented for CE/Linux path in this repository with minimal invasive changes,
reusing existing PHYDM RA mask and watchdog mechanisms.


## Recommended next steps (status)
1. Add retry smoothing (EWMA) before applying down-bias thresholds. **Implemented**.
2. Add temporary rate-up cooldown after high retry bursts. **Implemented**.
3. Evaluate adding queue/backlog guardrail (e.g., tx-drop growth or queue depth) for emergency downshift. **Planned**.
4. Add runtime knobs for retry thresholds and cooldown length via proc (`p4oc_ra`). **Implemented**.

## Evaluation (v2)
- Compared to baseline RA, P4OC now has:
  - bounded rate-up (`probe_step`) + hysteresis,
  - retry-smoothed down-bias,
  - cooldown that prevents immediate bounce-back after retry spikes.
- Expected effect: lower oscillation and fewer aggressive upshifts after transient loss.
- Remaining gap: no explicit queue-depth/backlog driven emergency downshift yet.
- Observability gap: `tx_rate_bmp` may not match instantaneous rate, so combine with `iw ... tx bitrate`.
