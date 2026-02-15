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

`echo "<enable> [max_ht_mcs] [interval_ms] [up_hysteresis] [probe_step] [retry_hi] [retry_low] [cooldown_hi] [cooldown_low] [rssi_th_ofst] [rssi_up_gap]" > p4oc_ra`

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
6. `p4oc_bw_hint` kbps values are moving averages over the last 5 readings to reduce 20ms jitter.

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


## Recommended next steps (v3 status)
1. Queue/backlog emergency downshift guardrail. **Planned**.
2. Extend `p4oc_bw_hint` with per-link telemetry (`curr_mcs`, `rssi`, trend, theoretical kbps). **Implemented**.
3. Remove Mbps-only dependency from app side, keep kbps-centric hint. **Implemented**.
4. Add AP-mode peer selection for telemetry when multiple stations linked. **Planned**.
5. Add runtime RSSI floor tuning knobs while preserving legacy behavior when P4OC off. **Implemented**.

## Evaluation (v3)
- Compared to baseline and v2:
  - App hint now better reflects low-rate reality (kbps-first output).
  - Runtime visibility now includes current rate/MCS/RSSI and a trend indicator derived from P4OC state.
  - Adds theoretical current/allowed kbps estimates for HT20/40 1SS path, improving operator intuition.
- Remaining gap:
  - queue/backlog not yet wired as explicit emergency downshift signal.
  - theoretical kbps output currently focused on HT1SS mapping (legacy/VHT path prints rate label but no full theoretical mapping yet).


## Next simplification step (implemented)

- Introduce `simple_mode` under `p4oc_ra` control and make it default `1`.
- In simple mode, keep only: fast interval + HT MCS cap + non-CCK guard for non-CCK links.
- Bypass advanced retry EWMA/cooldown/hysteresis shaping unless `simple_mode=0`.
- This reduces interacting knobs and makes behavior more deterministic in field deployments.
