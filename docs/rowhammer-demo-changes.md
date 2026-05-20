# RowHammer Demo Changes

This note records the local demo changes used to exercise Ramulator2's
RowHammer mitigation path from this `gem5-ramulator2` checkout.

## Goal

The demo is intentionally small. It does not try to model physical bit flips.
It creates a repeatable command-level RowHammer pattern and verifies that the
configured mitigation injects victim-row refresh commands.

The signal to look for is:

```text
VRR > 0
```

`VRR` means the RowHammer mitigation path issued victim-row-refresh commands.

## Integration State

The repository uses gem5 plus Ramulator2. In this checkout, the submodules were
initialized and the wrapper files were copied into the gem5 tree in the same
layout used by the Dockerfile:

```text
gem5/ext/ramulator2/ramulator2/
gem5/ext/ramulator2/SConscript
gem5/src/mem/Ramulator2.py
gem5/src/mem/ramulator2.cc
gem5/src/mem/ramulator2.hh
gem5/src/python/gem5/components/memory/ramulator_2.py
```

Ramulator2 was built successfully with this CMake compatibility flag because
the local CMake version rejects one old dependency policy by default:

```bash
cmake -S gem5/ext/ramulator2/ramulator2 \
  -B gem5/ext/ramulator2/ramulator2/build \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build gem5/ext/ramulator2/ramulator2/build -j 4
cp gem5/ext/ramulator2/ramulator2/build/ramulator2 \
  gem5/ext/ramulator2/ramulator2/ramulator2
```

The full gem5 build was not completed in this environment because
`python3-config` and `Python.h` are missing. Installing `python3-dev` or the
distribution-equivalent Python development package should unblock that step.

## Standalone Demo Files

The minimal standalone demo uses a load/store trace and a Ramulator2 YAML
configuration.

Trace file:

```text
example/hammer_ls.trace
```

Trace contents:

```text
LD 0x0
LD 0x40000
LD 0x0
LD 0x40000
LD 0x0
LD 0x40000
LD 0x0
LD 0x40000
LD 0x0
LD 0x40000
LD 0x0
LD 0x40000
```

The two addresses are selected so that, under the `RoBaRaCoCh` mapper for the
current DDR4 organization, they alternate between rows in the same DRAM bank.
That forces repeated row activation and precharge behavior.

Standalone YAML:

```yaml
Frontend:
  impl: LoadStoreTrace
  clock_ratio: 1
  path: example/hammer_ls.trace

MemorySystem:
  impl: GenericDRAM
  clock_ratio: 1000

  DRAM:
    impl: DDR4-VRR
    org:
      preset: DDR4_2Gb_x8
      channel: 1
      rank: 2
    timing:
      preset: DDR4_2400R

  Controller:
    impl: Generic
    Scheduler:
      impl: FRFCFS
    RefreshManager:
      impl: AllBank
    plugins:
      - ControllerPlugin:
          impl: OracleRH
          tRH: 4
          debug: false
      - ControllerPlugin:
          impl: CommandCounter
          path: ramulator_out/ddr4_standalone_oracle.cmds
          commands_to_count:
            - ACT
            - PRE
            - RD
            - REFab
            - VRR

  AddrMapper:
    impl: RoBaRaCoCh
```

Important choices:

- `DDR4-VRR` is required because plugins such as `OracleRH`, `PARA`, and
  `Graphene` issue `VRR` requests.
- `OracleRH` is used for a simple demo because it directly counts activations
  and issues `VRR` when `tRH` is reached.
- `tRH: 4` is deliberately low so the short trace triggers mitigation.
- `MemorySystem.clock_ratio: 1000` lets the DRAM controller drain enough
  commands before the standalone frontend finishes.

Run command:

```bash
gem5/ext/ramulator2/ramulator2/ramulator2 \
  -f example/DDR4-rowhammer-standalone.yaml
```

## gem5-Facing Demo Configs

The same idea can be used from gem5 by selecting `Ramulator2` as the memory
type and passing the Ramulator2 YAML through `--ramulator-config`.

Baseline command-counter config:

```yaml
DRAM:
  impl: DDR4
  timing:
    preset: DDR4_2400R
Controller:
  plugins:
    - ControllerPlugin:
        impl: CommandCounter
        path: ramulator_out/ddr4_baseline.cmds
        commands_to_count: [ACT, PRE, RD, WR, REFab]
```

Oracle RowHammer config:

```yaml
DRAM:
  impl: DDR4-VRR
  timing:
    preset: DDR4_2400R
Controller:
  plugins:
    - ControllerPlugin:
        impl: OracleRH
        tRH: 32
        debug: false
    - ControllerPlugin:
        impl: CommandCounter
        path: ramulator_out/ddr4_oracle.cmds
        commands_to_count: [ACT, PRE, RD, WR, REFab, VRR]
```

The gem5 run shape is:

```bash
gem5/build/X86/gem5.opt gem5/configs/deprecated/example/se.py \
  --cpu-type=TimingSimpleCPU \
  --caches \
  --l1d_size=64kB \
  --l1i_size=16kB \
  --mem-type=Ramulator2 \
  --mem-size=2GB \
  --ramulator-config=example/DDR4-rowhammer-oracle.yaml \
  --cmd=example/mm_base \
  --maxinsts=100000
```

## More Demo Configurations

The current pinned Ramulator2 version supports these DDR4 speed presets in both
`DDR4` and `DDR4-VRR`:

```yaml
timing:
  preset: DDR4_2400R
```

```yaml
timing:
  preset: DDR4_3200AA
```

For side-by-side DDR4 demos, keep the same trace and plugins, and only change
the timing preset:

```yaml
DRAM:
  impl: DDR4-VRR
  org:
    preset: DDR4_2Gb_x8
    channel: 1
    rank: 2
  timing:
    preset: DDR4_3200AA
```

Two standalone 3200 MT/s comparison configs were added:

```text
example/DDR4-3200AA-rowhammer-standalone.yaml
example/DDR5-3200BN-rowhammer-standalone.yaml
```

DDR4-3200AA uses `DDR4-VRR` plus `OracleRH`:

```yaml
DRAM:
  impl: DDR4-VRR
  org:
    preset: DDR4_2Gb_x8
    channel: 1
    rank: 2
  timing:
    preset: DDR4_3200AA
Controller:
  plugins:
    - ControllerPlugin:
        impl: OracleRH
        tRH: 4
```

DDR5-3200BN uses the built-in DDR5 timing model:

```yaml
DRAM:
  impl: DDR5
  org:
    preset: DDR5_8Gb_x8
    channel: 1
    rank: 2
  timing:
    preset: DDR5_3200BN
  RFM:
    BRC: 2
```

The DDR5 model requires the `RFM` parameter group because it computes RFM and
directed-RFM timings during DRAM setup.

The DDR5 trace uses a different second address:

```text
example/hammer_ls_ddr5.trace
```

```text
LD 0x0
LD 0x20000
...
```

With `rank: 2`, the DDR5 address mapper consumes an additional rank bit before
bankgroup/bank/row bits. `0x20000` is therefore the row stride needed to keep
the same rank/bank and alternate rows. Using `0x10000` changes the bank instead
of the row.

DDR5 support is present, but this pinned Ramulator2 source only includes DDR5
3200 timing presets:

```yaml
DRAM:
  impl: DDR5
  org:
    preset: DDR5_8Gb_x8
    channel: 1
    rank: 2
  timing:
    preset: DDR5_3200BN
```

A true DDR5 4800 MT/s demo needs either:

- a new `DDR5_4800*` timing preset added to `ramulator2/src/dram/impl/DDR5.cpp`,
  including the rate-dependent timing tables, or
- a complete custom timing block using `rate: 4800` plus all required cycle or
  nanosecond timing values.

Do not label a DDR5 run as 4800 MT/s if it is only using the built-in
`DDR5_3200*` preset.

For an apples-to-apples frequency comparison, use:

```bash
gem5/ext/ramulator2/ramulator2/ramulator2 \
  -f example/DDR4-3200AA-rowhammer-standalone.yaml

gem5/ext/ramulator2/ramulator2/ramulator2 \
  -f example/DDR5-3200BN-rowhammer-standalone.yaml
```

Important limitation: this source tree has DDR5 RFM/DRFM commands and timing,
but the included RowHammer mitigation plugins are DDR4-VRR oriented and do not
automatically issue DDR5 RFM commands. Also, no explicit on-die ECC model was
found in the pinned Ramulator2 source. Treat this as a DDR4-vs-DDR5 command and
timing comparison, not as a full DDR5 on-die ECC reliability model.

## 10,000-Read Comparison Runner

Use this script to reproduce the three-row comparison table:

```bash
bash script/run_rowhammer_compare_10000.sh
```

It generates temporary traces and configs under:

```text
ramulator_out/compare_10000/
```

The compared configurations are:

- DDR4-2400R with `DDR4-VRR` and `OracleRH`.
- DDR4-3200AA with `DDR4-VRR` and `OracleRH`.
- DDR5-3200BN with DDR5 command counters for `RFMab`, `RFMsb`, `DRFMab`, and
  `DRFMsb`.

The summary files are:

```text
ramulator_out/compare_10000/summary.csv
ramulator_out/compare_10000/summary.md
```
