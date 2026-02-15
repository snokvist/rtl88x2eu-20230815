# P4OC Rate Adaptation (RA) Mode

This document explains:
1. How to use the new `p4oc_ra` control.
2. What the driver currently uses to **raise** or **lower** allowed rates.
3. What is **not** used yet (important for test expectations).
4. An implementation/test log as we start validation.

---

## 1) What P4OC mode is intended to do

P4OC mode is a conservative link-stability profile for HT links.

When enabled, it adds three behaviors:
- **HT cap**: limit allowed HT rates to `MCS0..N` (intended use: `N=7`).
- **Faster RA refresh cadence**: dynamic check timer can run at 10–50 ms instead of 2000 ms.
- **Conservative upward changes**: a rate-mask expansion must pass a hysteresis counter before being applied.

The goal is to keep the link alive and avoid optimistic upshifts.

---

## 2) Proc interface and usage

A new proc entry is exposed per interface:

`/proc/net/<driver>/<iface>/p4oc_ra`

### Write format

```sh
# echo "<enable> [max_ht_mcs] [interval_ms] [up_hysteresis] [probe_step] [retry_hi] [retry_low] [cooldown_hi] [cooldown_low]" > p4oc_ra
```

### Examples

```sh
# Enable with defaults (max_ht_mcs=7, interval=20ms, up_hysteresis=3, probe_step=2)
echo "1" > /proc/net/<driver>/<iface>/p4oc_ra

# Explicit settings (recommended starting point)
echo "1 7 20 3 2 45 30 3 2" > /proc/net/<driver>/<iface>/p4oc_ra

# Disable
 echo "0" > /proc/net/<driver>/<iface>/p4oc_ra
```

### Read back

```sh
cat /proc/net/<driver>/<iface>/p4oc_ra
```

Readback includes:
- `enable`
- `max_ht_mcs`
- `interval_ms`
- `up_hysteresis`
- `probe_step`
- `retry_th_high`, `retry_th_low` (retry EWMA thresholds for down-bias)
- `cooldown_high`, `cooldown_low` (rate-up cooldown cycles after high retry)
- `effective_interval_ms` (actual clamped value used by timer logic)

---


### Interpreting iw and tx_rate_bmp output

- `iw dev wlan0 link` has both `rx bitrate` and `tx bitrate`:
  - `tx bitrate` is this STA's TX rate (affected by our RA mask changes).
  - `rx bitrate` is AP->STA direction (not directly controlled by this driver TX RA logic).
- `tx_rate_bmp` is an allowed-rate bitmap view, not necessarily the currently used per-packet rate.

So seeing e.g. `rx bitrate ... MCS14` while `tx bitrate ... MCS3` can still be consistent with P4OC
TX constraints.

## 3) Current rate-selection trigger logic (important)

## 3.1 Driver-side mask updates are RSSI-level driven

The driver recomputes allowed RA mask from:
- wireless mode / BW / streams,
- then RSSI level (`rssi_level`) via PHYDM floor table,
- then (in P4OC mode) retry-ratio guardrails,
- then P4OC cap/probe-step/hysteresis logic.

### RSSI floor table used by PHYDM
Base thresholds:
- `[20, 34, 38, 42, 46, 50, 100]`

PHYDM then applies a floor-up gap (`+3`) depending on current RA state, which provides built-in threshold hysteresis in level changes.

### Upward allowed-mask changes (rate-up side)
In P4OC mode:
- HT cap is applied first (`MCS0..max_ht_mcs`).
- Additional **probe-step cap** is applied from current HT Tx rate: mask is limited to at most
  `current_mcs + probe_step` (clamped by `max_ht_mcs`).
- If recomputed mask still adds higher bits (i.e. expansion), it is **not** applied immediately.
- A per-STA pending counter must reach `up_hysteresis` before applying.

So: **upward expansion is delayed and bounded**.

### Downward allowed-mask changes (rate-down side)
In P4OC mode:
- Retry ratio from FW RA report is smoothed by EWMA and used as an additional down-bias:
  - `retry_ewma >= 45`  => push RSSI level down by +2 levels (more conservative mask).
  - `retry_ewma >= 30`  => push RSSI level down by +1 level.
- High retry events also set a short rate-up cooldown (2-3 cycles) to avoid immediate bounce-back.
- If resulting mask does not expand (same or contracts), update is applied immediately.

So: **downward contraction is immediate and now also retry-sensitive**.

---

## 3.2 Is retransmission/PER/tx-queue used directly by this new P4OC layer?

Short answer: **partially yes now**.

- The updated P4OC additions now include direct use of FW-reported retry ratio (`curr_retry_ratio`)
  as a down-bias signal during mask recomputation.
- They still do **not** add explicit new checks on:
  - tx queue depth,
  - tx backlog.

However, after mask is sent to FW RA, the firmware RA may still choose the current rate within that allowed mask based on its own internal feedback/algorithms.

So for testing:
- Expect clear behavior in **allowed-rate envelope** (cap and conservative expansions).
- Do not expect a new explicit driver-side retry/PER trigger path from this P4OC patch alone.

---

## 4) Effective cadence / watchdog behavior in current implementation

- Legacy path uses 2000 ms dynamic checks.
- In P4OC mode, the dynamic check interval uses configured value clamped to `[10..50]` ms.
- Existing 1-shot path that sets timer to `1` ms in specific states remains unchanged.

This means P4OC mode increases the frequency of dynamic check work and RA-mask reevaluation.

---

## 5) Busybox test tools

Added scripts (busybox `/bin/sh` compatible):
- `tools/p4oc/p4oc_ra_config.sh`
- `tools/p4oc/p4oc_ra_smoke_test.sh`
- `tools/p4oc/p4oc_ra_monitor.sh`
- `tools/p4oc/p4oc_bw_hint.sh`

Typical flow:

```sh
# configure
sh tools/p4oc/p4oc_ra_config.sh wlan0 1 7 20 3 2

# smoke test (readback + interval range check)
sh tools/p4oc/p4oc_ra_smoke_test.sh wlan0

# monitor during RF tests
sh tools/p4oc/p4oc_ra_monitor.sh wlan0 60
```

---


## 5.1 Bandwidth hint for adaptive streaming apps

A read-only proc endpoint is provided for app-side bitrate adaptation:

`/proc/net/<driver>/<iface>/p4oc_bw_hint`

Output fields:
- `tx_kbps`: current TX throughput estimate from driver traffic stats.
- `rx_kbps`: current RX throughput estimate from driver traffic stats.
- `app_hint_kbps`: conservative bitrate suggestion for app encoders/ABR logic
  (`min(tx,rx)` when bidirectional traffic exists, otherwise max active direction,
  then 20% guard band).
- `sample_interval_ms`: last interval used for throughput sample calculation.
- `poll_recommend_ms`: recommended polling period (same source as dynamic check timer).
- `curr_tx_rate`: current TX rate label from driver (`HDATA_RATE`).
- `curr_mcs`: current HT MCS index when in HT1SS path (otherwise `-1`).
- `curr_rssi`: current STA RSSI.
- `trend`: current P4OC tendency estimate (`down`, `down_cooldown`, `hold`, `up_candidate`, `legacy_ra`).
- `theoretical_current_kbps`: theoretical PHY kbps for current selected HT MCS (HT20/HT40, SGI-adjusted).
- `theoretical_allowed_kbps`: theoretical PHY kbps for current allowed top HT MCS under cap/probe policy.

Example integration for streamers:
1. Poll every 0.5s–1s.
2. Use `app_hint_kbps` as target video bitrate ceiling (already guard-banded).
3. Only increase application bitrate after N consecutive higher samples
   (to avoid oscillations), but decrease immediately on drops.


### Update cadence (answering "how often is this updated?")

`p4oc_bw_hint` itself is computed on read, but it consumes `cur_tx_tp/cur_rx_tp` that are refreshed in
`collect_traffic_statistics()` each time the dynamic check handler runs.

So the effective update cadence is:
- **Default mode**: about 2000 ms.
- **P4OC mode**: `p4oc_ra interval_ms`, clamped to **10..50 ms**.

If you want streamer checks at 20–50 ms, set:

```sh
echo "1 7 20 3 2 45 30 3 2" > /proc/net/<driver>/<iface>/p4oc_ra
```

Then poll `p4oc_bw_hint` at or slightly above `poll_recommend_ms`.

## 6) Implementation / testing log

## 2026-02-15 (initial implementation pass)

### Added
- Proc control `p4oc_ra` (get/set).
- Adapter runtime knobs for P4OC settings.
- Dynamic-check interval helper with P4OC clamp (10–50 ms).
- PHYDM mask cap helper for HT `MCS0..N`.
- Per-STA pending hysteresis for upward mask expansion.
- Busybox helper scripts.

### Known limitations to verify next
- `probe_step` is now wired as a mask bound (`current_mcs + probe_step`) for conservative upward probing.
- Retry-ratio path now uses EWMA smoothing and temporary up-cooldown after high retry events.
- Queue-depth/backlog is still not used directly for emergency downshift.
- Need real-world RF tests to validate oscillation reduction and link survival under fades/interference.

### Next planned validation
1. Verify cap enforcement (no HT MCS >7 in P4OC mode).
2. Verify upshift latency increases with `up_hysteresis`.
3. Verify downshift remains responsive under degraded RSSI.
4. Compare stability against baseline (`p4oc_ra=0`).


## 7) Evaluation (v2 vs baseline RA)

### What changed in v2
- Added retry-ratio EWMA smoothing before applying P4OC down-bias thresholds.
- Added temporary rate-up cooldown after high retry events to reduce bounce-back.

### Fit-for-purpose assessment
- Better fit for link-stability objective than baseline RA and earlier P4OC version:
  - Upward moves remain bounded (`probe_step`) and hysteresis-gated.
  - Downward moves now react to **smoothed** retry ratio, reducing spike sensitivity.
  - Cooldown suppresses immediate re-expansion after short loss bursts.
- Remaining limitations:
  - No explicit tx queue/backlog emergency downshift path yet.
  - Thresholds/cooldown still static (not runtime-tunable yet).

### Recommended next implementation step
- Add queue/backlog signal (or tx-drop delta) as additional emergency downshift trigger.
- Add live-rate diagnostics into monitor helper to correlate `tx_rate_bmp` with observed `tx bitrate`.
