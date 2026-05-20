# DDR5 RFM RowHammer Mitigation Plugin

This repository includes a top-level patch that adds a DDR5-specific
RowHammer mitigation plugin to Ramulator2.

Patch:

```text
patches/ramulator2-ddr5-rfm-plugin.patch
```

Apply script:

```bash
bash script/apply_ddr5_rfm_plugin.sh
```

The plugin implementation is named:

```text
DDR5RFM
```

## What It Does

`DDR5RFM` tracks row activations per bank. When a row reaches the configured
activation threshold, it injects a high-priority DDR5 RFM-family request.

The default request is:

```yaml
request: directed-rfm
```

That maps to the DDR5 command:

```text
DRFMab
```

Other supported request values are:

```text
rfm
same-bank-rfm
directed-rfm
same-bank-directed-rfm
```

## Demo Config

Standalone DDR5 demo:

```text
example/DDR5-3200BN-rfm-standalone.yaml
```

Run:

```bash
gem5/ext/ramulator2/ramulator2/ramulator2 \
  -f example/DDR5-3200BN-rfm-standalone.yaml

cat ramulator_out/ddr5_3200bn_rfm.cmds
```

Observed short-trace result:

```text
PREA, 1
DRFMab, 1
RFMsb, 0
RFMab, 0
REFsb, 0
REFab, 2
RD, 11
PRE, 9
DRFMsb, 0
ACT, 11
```

The key line is:

```text
DRFMab, 1
```

This confirms that the plugin saw enough row activations to cross `tRH` and
issued a DDR5 directed RFM request.

## 10,000-Read Comparison Result

The main comparison runner now includes a fourth row for the new plugin:

```bash
bash script/run_rowhammer_compare_10000.sh
```

Observed result:

```text
| Config | DRAM model | Mitigation model | Reads | ACT | PRE | REFab | VRR | RFM/DRFM | Cycles | Finding |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DDR4-2400R | DDR4-VRR | OracleRH tRH=4 | 10000 | 9999 | 8952 | 2134 | 2135 | 0 | 9999000 | VRR triggered |
| DDR4-3200AA | DDR4-VRR | OracleRH tRH=4 | 10000 | 9999 | 9197 | 1602 | 1602 | 0 | 9999000 | VRR triggered |
| DDR5-3200BN | DDR5 | Command count only | 10000 | 9999 | 8431 | 3214 | 0 | 0 | 9999000 | RFM/DRFM not issued |
| DDR5-3200BN-RFM | DDR5 | DDR5RFM tRH=4 directed-rfm | 10000 | 9999 | 8431 | 3214 | 0 | 357 | 9999000 | RFM/DRFM issued |
```

The key new line is:

```text
DDR5-3200BN-RFM ... RFM/DRFM = 357
```

This demonstrates that the plugin converts activation-threshold crossings into
DDR5 RFM-family commands. With the default `request: directed-rfm`, the counted
commands are `DRFMab`.

## Configuration Knobs

Example:

```yaml
- ControllerPlugin:
    impl: DDR5RFM
    tRH: 4
    request: directed-rfm
    reset_on_refresh: true
    debug: false
```

`tRH` is the activation threshold.

`request` selects the DDR5 RFM-family request.

`reset_on_refresh` clears tracked activation counts on all-bank refresh.

`debug` prints activation and mitigation events.

## Build

After applying the patch, rebuild Ramulator2:

```bash
cmake --build gem5/ext/ramulator2/ramulator2/build -j 4
cp gem5/ext/ramulator2/ramulator2/build/ramulator2 \
  gem5/ext/ramulator2/ramulator2/ramulator2
```
