# rx_ant_metrics proc usage

This document describes how to use:

- `/proc/net/rtl88x2eu/<iface>/rx_ant_metrics`

The proc node supports both:

- `cat rx_ant_metrics` (read current metrics)
- `echo ... > rx_ant_metrics` (configure what metrics context to show)

---

## Output format (machine parseable)

`cat rx_ant_metrics` prints CSV-like key/value records:

1. Header/context line:

```
profile=<name>,use_target_rate=<0|1>,target_rate=<0-255>,effective_rate=<0-255>,odm_rate=<0-255>,rx_path_bmp=0xNN,rx_cnt=<n>,store_raw=<0|1>,metric_source=<name>
```

2. One line per active RX path:

```
path=<A|B|C|D>,rssi=<0-100>,lock_quality=<0-100>,snr=<0-100>,rx_pwr_dbm=<signed>,snr_latest=<signed>
```

If no active RX path exists, output contains:

```
path=none
```

---

## Write commands

You can combine tokens in one echo, separated by spaces/commas.

### 1) Select profile

- `echo profile=auto > rx_ant_metrics`
- `echo profile=last > rx_ant_metrics`
- `echo profile=ofdm > rx_ant_metrics`
- `echo profile=1ss > rx_ant_metrics`
- `echo profile=2ss > rx_ant_metrics`
- `echo profile=3ss > rx_ant_metrics`
- `echo profile=4ss > rx_ant_metrics`

Short aliases are also accepted (`auto`, `last`, `ofdm`, `1ss`, `2ss`, `3ss`, `4ss`).

### 2) Select target rate context

- `echo rate=<desc_rate_value> > rx_ant_metrics`
- `echo <desc_rate_value> > rx_ant_metrics`  
  (bare numeric is treated like `rate=<...>`)
- `echo rate=auto > rx_ant_metrics`  
  (disable forced target-rate context)
- `echo rate_off > rx_ant_metrics`  
  (same as `rate=auto`)

### 3) Enable/disable raw packet metric storage

- `echo store=1 > rx_ant_metrics`
- `echo store=0 > rx_ant_metrics`

`store=1` is useful with `profile=last` (last-packet raw metrics).

### 4) Combined examples

- `echo "profile=1ss rate=0x14" > rx_ant_metrics`
- `echo "profile=ofdm rate=auto" > rx_ant_metrics`
- `echo "profile=last store=1" > rx_ant_metrics`

---

## Profiles and cfg mask meaning

Internally the driver stores config in `rx_ant_dbg_cfg`:

- **bits [2:0]** = profile selector
- **bit [3]** = `use_target_rate` flag

### Profile selector values (bits [2:0])

| Value | Name  | Meaning |
|---:|---|---|
| 0 | auto | Derive profile from effective rate |
| 1 | last | Last captured per-packet raw metrics |
| 2 | ofdm | PHYDM averaged OFDM metrics |
| 3 | 1ss | PHYDM averaged 1 spatial stream metrics |
| 4 | 2ss | PHYDM averaged 2 spatial stream metrics |
| 5 | 3ss | PHYDM averaged 3 spatial stream metrics |
| 6 | 4ss | PHYDM averaged 4 spatial stream metrics |

### Bit masks

- `RX_ANT_DBG_PROFILE_MASK = 0x07` (bits [2:0])
- `RX_ANT_DBG_USE_TARGET_RATE = 0x08` (bit [3])

---

## Human-readable rate mapping (desc rate values)

These are the driver descriptor rate values accepted by `rate=<...>`.

### Legacy examples

| Mode | Human readable | Value |
|---|---|---:|
| CCK | 1M | `0x00` |
| OFDM | 6M | `0x04` |
| OFDM | 54M | `0x0B` |

### HT (11n) range

- `MCS0 .. MCS31` = `0x0C .. 0x2B`

Formula:

- `value = 0x0C + mcs_index`

Examples:

- MCS0 -> `0x0C`
- MCS1 -> `0x0D`
- MCS7 -> `0x13`
- MCS8 -> `0x14`
- MCS15 -> `0x1B`

### VHT (11ac) range

- `VHT1SS_MCS0 .. VHT4SS_MCS9` = `0x2C .. 0x53`

Formula:

- `value = 0x2C + (nss - 1) * 10 + mcs`

Examples:

- VHT1SS MCS0 -> `0x2C`
- VHT1SS MCS9 -> `0x35`
- VHT2SS MCS0 -> `0x36`
- VHT4SS MCS9 -> `0x53`

---

## MCS to profile guidance

If you want a profile explicitly matching your MCS class:

- HT MCS0-7 / VHT 1SS -> `profile=1ss`
- HT MCS8-15 / VHT 2SS -> `profile=2ss`
- HT MCS16-23 / VHT 3SS -> `profile=3ss`
- HT MCS24-31 / VHT 4SS -> `profile=4ss`

Examples:

- Investigate HT MCS1:
  - `echo "profile=1ss rate=0x0D" > rx_ant_metrics`
- Investigate HT MCS8:
  - `echo "profile=2ss rate=0x14" > rx_ant_metrics`
- Investigate VHT2SS MCS3:
  - `echo "profile=2ss rate=0x39" > rx_ant_metrics`

---

## Why some fields can be zero

- `profile=last` uses last captured raw packet metrics and depends on packet sampling/storage.
- If no suitable recent sample exists (or storage disabled), some last-packet fields can be `0`/unset-like.
- For more stable tuning views, use averaged profiles (`ofdm`, `1ss`, `2ss`, `3ss`, `4ss`).

