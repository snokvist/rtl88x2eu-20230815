# `rx_ant_metrics` guide (power/MCS tuning focused)

Proc node:

- `/proc/net/rtl88x2eu/<iface>/rx_ant_metrics`

Use it to inspect **per-rate receive quality** while tuning TX power and selected MCS profile.

---

## Quick start

```sh
cd /proc/net/rtl88x2eu/wlan0

# 1) Tune for 1SS operation, with a longer sample window for stable pkt counters
echo "profile=1ss rate=auto sample_ms=3000" > rx_ant_metrics
cat rx_ant_metrics

# 2) Force HT MCS1 context and compare
# HT MCS1 -> 0x0D
# (profile=1ss is the matching SS family)
echo "profile=1ss rate=0x0D sample_ms=3000" > rx_ant_metrics
cat rx_ant_metrics

# 3) Snapshot last-packet view (good for instantaneous checks)
echo "profile=last store=1 sample_ms=0" > rx_ant_metrics
cat rx_ant_metrics
```

---

## Output format (machine-parseable)

`cat rx_ant_metrics` prints key/value CSV-like lines.

### 1) Header line

```text
profile=<name>,use_target_rate=<0|1>,target_rate=<0-255>,effective_rate=<0-255>,odm_rate=<0-255>,rx_path_bmp=0xNN,rx_cnt=<n>,store_raw=<0|1>,metric_source=<name>,sample_ms=<0-10000>
```

### 2) Table rows (selected profile family)

```text
row=<label>,rate_idx=<n>,pkt_cnt=<n>,rssi_a=<n>,rssi_b=<n>,lock_a=<n>,lock_b=<n>,snr_a=<n>,snr_b=<n>
```

### 3) Per-path summary

```text
path=<A|B>,rssi=<0-100>,lock_quality=<0-100>,snr=<0-100>,snr_latest=<signed>
```

> Notes
>
> - Output is intentionally A/B-only (2-path focused).
> - `pkt_cnt` is a delta over `sample_ms` when `sample_ms > 0`.

---

## What each profile means

- `profile=last`  
  Uses latest raw packet values. Useful for immediate/instant snapshots.
- `profile=ofdm`  
  Emits OFDM legacy table rows (`OFDM_6M .. OFDM_54M`).
- `profile=1ss`, `2ss`, `3ss`, `4ss`  
  Emits the table for that spatial-stream family:
  - HT rows (`ht_mcs...`)
  - VHT rows (`vht...`) when available in build
- `profile=auto`  
  Selects family from effective rate context.

---

## Write controls

You can combine tokens in one command.

### Profile selection

```sh
echo "profile=auto" > rx_ant_metrics
echo "profile=last" > rx_ant_metrics
echo "profile=ofdm" > rx_ant_metrics
echo "profile=1ss"  > rx_ant_metrics
echo "profile=2ss"  > rx_ant_metrics
```

(Short aliases also work: `auto`, `last`, `ofdm`, `1ss`, ...)

### Rate context selection

```sh
echo "rate=0x0D" > rx_ant_metrics   # force HT MCS1 context
echo "13"        > rx_ant_metrics   # same as above (bare numeric)
echo "rate=auto" > rx_ant_metrics   # stop forcing rate context
echo "rate_off"  > rx_ant_metrics   # same as rate=auto
```

### Raw packet storage toggle (used by `profile=last`)

```sh
echo "store=1" > rx_ant_metrics
echo "store=0" > rx_ant_metrics
```

### Sampling window for `pkt_cnt`

```sh
echo "sample_ms=1000" > rx_ant_metrics
echo "sample_ms=3000" > rx_ant_metrics
echo "sample_ms=0"    > rx_ant_metrics   # immediate counters (no wait)
```

- Larger `sample_ms` => more stable/non-zero `pkt_cnt` under low traffic.
- Smaller `sample_ms` => faster reads but noisier/sparser counts.

---

## Why this is useful for power-output tuning

When tuning TX power, you usually want to hold a **rate family** and observe quality trends:

- `rssi_*` tracks received signal level trend.
- `lock_*` (EVM-derived quality) tracks constellation quality trend.
- `snr_*` tracks path SNR trend.
- `pkt_cnt` shows whether traffic actually occurred in that row during the sample window.

### Recommended workflow

1. Pick profile matching your operating mode (you said mostly 1SS):
   - `echo "profile=1ss rate=auto sample_ms=3000" > rx_ant_metrics`
2. Collect baseline output at current power.
3. Change TX power step.
4. Re-read and compare rows with non-zero `pkt_cnt`:
   - prefer settings where `lock_*`/`snr_*` improve or stay stable,
   - avoid settings where `lock_*` drops while `rssi_*` rises (common distortion sign).
5. Validate on your actually used rows (e.g., HT MCS0-7 / VHT1SS MCS0-9 for 1SS).

---

## Useful rate references

Descriptor values accepted by `rate=`:

- HT MCS range: `0x0C .. 0x2B` (`MCS0 .. MCS31`)
  - formula: `0x0C + mcs`
  - examples: `MCS0=0x0C`, `MCS1=0x0D`, `MCS7=0x13`, `MCS8=0x14`
- VHT range: `0x2C .. 0x53` (`VHT1SS_MCS0 .. VHT4SS_MCS9`)
  - formula: `0x2C + (nss-1)*10 + mcs`

Profile mapping reminder:

- HT MCS0-7 / VHT 1SS => `profile=1ss`
- HT MCS8-15 / VHT 2SS => `profile=2ss`
- HT MCS16-23 / VHT 3SS => `profile=3ss`
- HT MCS24-31 / VHT 4SS => `profile=4ss`

