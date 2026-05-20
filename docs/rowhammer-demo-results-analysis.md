# RowHammer Demo Results And Analysis

This note records the observed command-counter result from the standalone
RowHammer mitigation demo.

## Run

Command:

```bash
gem5/ext/ramulator2/ramulator2/ramulator2 \
  -f example/DDR4-rowhammer-standalone.yaml
```

Output summary from Ramulator2:

```text
Frontend:
  impl: LoadStoreTrace

MemorySystem:
  impl: GenericDRAM
  total_num_other_requests: 0
  total_num_write_requests: 0
  total_num_read_requests: 12
  memory_system_cycles: 11000
  DRAM:
    impl: DDR4-VRR
  AddrMapper:
    impl: RoBaRaCoCh
  Controller:
    impl: Generic
    id: Channel 0
    Scheduler:
      impl: FRFCFS
    RefreshManager:
      impl: AllBank
    ControllerPlugin:
      impl: OracleRH
    ControllerPlugin:
      impl: CommandCounter
```

Command-counter output:

```text
PREA, 1
VRR, 2
REFab, 2
RD, 11
PRE, 9
ACT, 11
```

## Result Meaning

The key finding is:

```text
VRR, 2
```

This means the configured RowHammer mitigation issued two victim-row-refresh
commands during the short trace.

Command meanings:

- `ACT`: a DRAM row activation.
- `PRE`: a precharge that closes an open bank row.
- `RD`: a read command.
- `REFab`: normal all-bank refresh.
- `PREA`: precharge-all, used before refresh-like operations when needed.
- `VRR`: victim-row refresh, the mitigation response.

The demo trace alternates between two addresses:

```text
0x0
0x40000
```

With the selected DDR4 organization and `RoBaRaCoCh` address mapper, these
addresses map to different rows in the same bank. Alternating them prevents a
simple row-buffer-hit stream and produces repeated activation/precharge
behavior, which is the command-level pattern needed to exercise RowHammer
defenses.

## Why VRR Was Triggered

The YAML config uses:

```yaml
impl: OracleRH
tRH: 4
```

`OracleRH` tracks activation counts per row. When a row reaches `tRH`, it sends
a `victim-row-refresh` request. In `DDR4-VRR`, that request maps to the `VRR`
command.

The observed `ACT, 11` count shows the trace created repeated row activations.
The observed `VRR, 2` count shows those activations crossed the configured
threshold twice.

## Parsing Method

Use this parser to turn the command-counter file into an explanation:

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("ramulator_out/ddr4_standalone_oracle.cmds")
counts = {}

for line in path.read_text().splitlines():
    if not line.strip():
        continue
    cmd, count = line.split(",")
    counts[cmd.strip()] = int(count.strip())

for name in ["ACT", "PRE", "RD", "REFab", "PREA", "VRR"]:
    print(f"{name:5s}: {counts.get(name, 0)}")

print()
if counts.get("VRR", 0) > 0:
    print("Finding: RowHammer mitigation was triggered.")
    print("Reason : activation count crossed the configured tRH threshold.")
else:
    print("Finding: RowHammer mitigation was not triggered.")
    print("Reason : no row reached the configured tRH threshold, or the run")
    print("         ended before queued mitigation commands were issued.")
PY
```

Expected interpretation for the recorded result:

```text
Finding: RowHammer mitigation was triggered.
Reason : activation count crossed the configured tRH threshold.
```

## New Findings

1. The standalone frontend stops when the trace has been injected, not when all
   memory-controller queues are fully drained. A very small
   `MemorySystem.clock_ratio` can therefore undercount late commands such as
   `VRR`. Using `MemorySystem.clock_ratio: 1000` made the short demo produce a
   visible mitigation result.

2. This is a mitigation-trigger demo, not a bit-flip demo. The current result
   proves that row activation tracking and victim-row refresh insertion are
   working. It does not prove a physical fault model or data corruption event.

3. The pinned Ramulator2 version has ready-to-use DDR4 2400 and DDR4 3200
   presets in `DDR4-VRR`. It does not have a ready-to-use DDR5 4800 preset.
   DDR5 4800 should be added as a timing-model extension before presenting a
   DDR5 4800 result.

4. The gem5 integration path is structurally prepared, but this machine still
   needs Python development headers and `python3-config` before `gem5.opt` can
   be built.

## Suggested Next Experiments

Run the same trace with different `tRH` values:

```yaml
tRH: 2
tRH: 4
tRH: 8
tRH: 100
```

Expected trend:

- Lower `tRH`: more `VRR` commands.
- Higher `tRH`: fewer or zero `VRR` commands.

Run the same trace with DDR4 speed presets:

```yaml
preset: DDR4_2400R
preset: DDR4_3200AA
```

Expected trend:

- The number of injected `VRR` commands should be primarily threshold-driven.
- Timing changes should affect cycle counts and scheduling, especially
  `memory_system_cycles`, not the basic fact that mitigation triggers when the
  activation threshold is crossed.
